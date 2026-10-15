# Native TLS client-close ordering — independent SPEC1

**PASS_SOURCE_ONLY — 12/12 checks; no findings.** The unadopted proposal is a bounded fixture ordering correction and preserves the failing `:killed` assertion. This is neither runtime PASS nor candidate2 acceptance.

Task `native_tls_close_order_spec1`, direct parent assignment, reviewer `/root/native_tls_spec2`. Repository R: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; baseline HEAD `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Root retains repo/runtime/build/formatter/Git/process custody. Only these `/tmp` review reports were written; existing task changes preserved. Counters remain 21 failed GREEN / 23 root events, Astra 2/2 exhausted; no repair/recovery round added.

## Evidence and root cause

Fresh TLS receipt SHA `b39c05bca4f3192ad902c8f8ca12842264e7961e8ebe64481169f53b66ff21c9` and diagnostic receipt SHA `bb78ba8e641510cf724e208904428268cc74fd0fd79d087a6064491c2b6ffe73` each record actual **41 tests / 1 failure**, exit2, joined, no timeout, source stable, zero skips/exclusions. Independently recomputed log hashes match. Both receipts' before/after maps equal and all198 current source files match; no source mismatch. These failures remain FAIL.

Diagnostic log lines40–58 show both actual pre-close workers waiting in `{Gaoxy.Proxy.HTTP,:await_cleanup,1}` with native stream1 still present and writer waiting. H2c original worker later exits `:normal`; http2 original worker exits `:killed`. In http2 the owner exits `{:shutdown,:peer_closed}` and writer exits `:normal`; the original worker is the actor failing the unchanged allowed set `[:normal,:noproc,:shutdown]`.

Source supports the ordering diagnosis:

- `deps/http_fetch/lib/http/request_completion.ex:2` describes cleanup of upstream tracked request resources. It cannot certify downstream Gaoxy pump return.
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:1118` separately waits for genuine Session guardianDOWN before returning the native Exchange.
- `apps/gaoxy_http/lib/gaoxy/http/http2/stream.ex:16` calls the endpoint, finishes the response, then sends actual `h2_stream_done` at :57 and returns.
- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex:1099` processes authenticated stream-done and on normal local_closed/eof uses `discard(state,id,false)`. :1286 discards the stream, demonitoring/removing it. In contrast, `close/1:1364` kills every still-listed worker and stops the writer. Immediate client close after upstream await races the downstream pump/stream return.

## Proposal and preserved assertions

Patch `/tmp/gaoxy-group-native-tls-close-order1.patch` SHA `6b40b036469187b3944c0a5f7071cd070c6eddca7eebfe36ca143a5b869a91a8` applies in memory to exactly one existing source context. Original TLS test SHA is `601d497749e5daee3c4dc43d6351ddcc70abe5bda17f888be49eee5cd2be4ea3`; prospective insertion result SHA is `f0f44cdbb02845fddf33b76a7d0f34379630c584c2b5d8e161492354979e951d`. It remains unadopted at review.

The patch inserts11 lines immediately after original `RequestCompletion.await(completion,@timeout)==:ok` and before original `:ssl.close(socket)`. It first waits until the exact observed original worker is dead, then until native owner state has no stream1, and asserts the exact owner and originally captured writer remain alive before deliberate client-close. `G.eventually` delegates to existing fixed fixture `eventually/2` (:629) with a finite deadline/assertion and1ms bounded polling; `:sys.get_state` is a bounded OTP call. A stuck/missing owner, stuck worker, lingering stream or dead writer fails rather than succeeding by timeout or teardown.

Neither barrier receives/flushes a DOWN. The original monitors were installed while owner/writer/worker were alive; their original join loop and reason sets are unchanged. An independently killed worker may satisfy `not Process.alive?`, but its existing queued DOWN still carries `:killed` and fails the unchanged later assertion. The stream barrier cannot mask an abnormal reset or worker death reason. Waiting for stream removal prevents client close from intentionally killing a remaining live request; it does not broaden any accepted exit set.

The diff contains **zero removals**,11 insertions and no other files. All original100 assertion-containing lines remain in order, with exactly2 new alive assertions. The full original source is retained, including:

- full SSL ownership/Plug equality, forged-caller/stream/token and expired metadata rejection;
- exact native worker/lease/native owner reservation identity;
- original completion identity, full16,478,862 Service cleanup bytes and exact lease/guardian;
- complete200 empty response and genuine upstream completion await;
- each original owner/writer/worker monitor join and allowed reason set (worker `:killed` stays forbidden);
- native active0/cleanup_pending0/retained_bytes0 and cleanup_failed:nil, bounded high-water, real service removal;
- unchanged `G.clean`, no extra request and `G.close` actual actor/resource/peer joins and physical termination expectations.

No completion substitution, cancellation, early Service removal, skip, retry, reason expansion, forced successful cleanup, reservation adjustment or production change occurs. The existing `on_exit` still closes the client on failure; that teardown does not become positive evidence.

## Validation and limits

Read-only commands: current path/branch/HEAD/status; exact patch and sha256; scoped source and diagnostic reads; Python receipt/log/198-source hash verification; in-memory unified-context application and original assertion-sequence preservation. All finished exit0; no owned running command remains. No Mix, formatter, runtime, build, Git mutation, process control or repository write ran. Reports themselves are the only writes.

Source review authorizes root to adopt this exact proposed fixture correction within the existing local repair authorization, followed by independent CODE review and fresh runtime verification. Actual TLS41/0 and required post-change gates remain NOT RUN for this proposal. Do not infer repair success or stage acceptance until those executed checks pass. No product decision or external permission is needed. Historical negative TLS/browser `UNCONFIRMED_WITH_RETAINED_FAILURE` remains unchanged.
