# Browser header contract review

Task `h2_browser_header_contract_spec1`: DONE; contract diagnosis and repaired-probe static readiness complete. Read-only direct assignment at baseline `8f6b884524d81d8defa7c5081230b8ab635e8107`, worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.

**Fetch.continueRequest is not a supported bypass for Proxy-Authorization on the reviewed Chromium source.** FetchHandler validates each overridden request header with `network::IsRequestHeaderSafe`, which rejects every case-insensitive `Proxy-` prefix and returns `InvalidParams("Unsafe header: Proxy-Authorization")`. `Authorization` is deliberately allowed. CDP's generic headers parameter does not promise unrestricted header names.

`Network.setExtraHTTPHeaders` initially checks header syntax only. Later network request validation rejects unsafe headers with `ERR_INVALID_ARGUMENT`. This matches the parent's safe-log observation: navigation failed immediately after both synthetic headers were installed, before host capture. It strongly supports header rejection before transport; the local runtime root cause remains a hypothesis until the differential runs. Public source was fetched from Chromium main (observed commit `317846d579b277c68d110b40185c7d64de81a3f2`); exact installed Chrome product/revision has not been verified by this reviewer.

References:

- https://github.com/chromium/chromium/blob/main/content/browser/devtools/protocol/fetch_handler.cc#L280 and #L427
- https://github.com/chromium/chromium/blob/main/services/network/public/cpp/header_util.cc#L113
- https://github.com/chromium/chromium/blob/main/content/browser/devtools/protocol/network_handler.cc#L2609
- https://github.com/chromium/chromium/blob/main/services/network/cors/cors_url_loader_factory.cc#L412 and #L961
- https://chromedevtools.github.io/devtools-protocol/tot/Fetch/#method-continueRequest

The proposed four-cell H1 diagnostic is sufficient first: none, origin Authorization only, Proxy-Authorization only, both. Use unique paths and record actual synthetic-only server arrivals, CDP navigation outcomes and actual Browser.getVersion. If none/origin arrive200 while proxy/both fail ERR_INVALID_ARGUMENT without arrival, there is no need to expand into an H2 suite to isolate this header restriction. Only an unexpected H1 result warrants a bounded equivalent TLS/H2 comparison. All results remain diagnostics, not Gaoxy acceptance.

Initial static review of `/tmp/gaoxy-h2-browser-header-probe1.py` identified two narrow readiness findings, now resolved by root and independently rechecked:

1. `HEADER-DIAG-01`, line29: the non-daemon server starts before cleanup ownership. Extraction/assertion/node-check/import/prctl failure can hang with the listener alive. Move fallible setup before server start or place server setup immediately under guaranteed bounded cleanup.
2. `HEADER-DIAG-02`, line77: startup/event failures leave `ready/results` unassigned, so finally masks the primary error, and the receipt always labels the diagnostic complete. Initialize partial fields; preserve the original failure and explicit failed/incomplete status while recording actual cleanup.

Repaired probe static readiness: **PASS** at SHA256 `873c266241624f539d30f17aef55501517b960ed381cdf8686ffa6262a608f2d`. Fallible pure setup now precedes live server setup under try/finally; partial fields, primary traceback and cleanup errors are preserved; failure produces DIAGNOSTIC_FAILED/exit1. The probe retains genuine header arrival, unique paths, no raw NetLog, file argv slice2, explicit Browser.close and original Actor joins. Root was notified before runtime consumption. No runtime result is claimed.

A browser origin-only Authorization marker plus exact proxy absence is a legitimate compatibility/credential-isolation contract if the design/plan explicitly distinguish it from positive stripping. Require the exact origin credential at genuine Gaoxy ingress and unchanged upstream, proxy absence at both, and no host fabrication. Preserve all unchanged socket cells that genuinely send Proxy-Authorization and assert upstream stripping. Preserve original browser failure and diagnostic evidence, refreeze the changed source/docs and obtain fresh independent review before acceptance. Removing injection/assertions while continuing to claim browser stripping is invalid; the original frozen candidate is superseded rather than retroactively passed. `continueWithAuth` is genuine challenge response, not an arbitrary direct-origin header setter.

Reviewer executed0tests,0builds and0browser/candidate runtimes; no repository/Git/dependency changes. All read-only commands finished. One optional public test-source lookup returned404; no test evidence is claimed. Reviewer repair rounds0, inherited counters unchanged; root owns runtime repairs and current counters. Only assigned `/tmp` reports were written. No browser/final/Task5/M3 acceptance.
