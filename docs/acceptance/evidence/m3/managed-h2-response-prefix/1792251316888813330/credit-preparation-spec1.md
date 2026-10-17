# Upstream-credit preparation SPEC1

Verdict: **FAIL — one P2 draft finding**,17/18checks pass. Preparation only; no next-stage entry/runtime acceptance.

F1: Plan1 lines48–54 constructs fresh `h2.settings.Settings` from only window1/optionalmax-streams. Installed public H2Connection source353–359 initializes MAX_CONCURRENT_STREAMS100 and MAX_HEADER_LIST_SIZE65536; fresh Settings defaults omit both (fallbacks2**32+1/None). Hold mode therefore removes unrelated advertised limits,contrary to the unchanged-cap contract.

Fix the hold-mode initial_values by copying current public `conn.local_settings.items()` before overriding INITIAL_WINDOW_SIZE and any explicit existing max-streams value. Preserve old default-off/max-streams behavior exactly; seed from current items only when hold mode is enabled. Update/rebind the draft and independently recheck. No product decision or current-prefix runtime repair follows.

The rest of the proposed proof is sound at specification level: actual same-connection SETTINGS ACK precedes complete native body2/trailers submission; real firstDATA1 with remote window0 and positive connection window establishes stream-credit exhaustion; original authentic pending ownership precedes explicit real stream/connection WINDOW_UPDATE1; actual second byte,exact ordered request/response trailers,terminal bytes and original cleanup follow. Public hyper-h2 receive/window-update semantics,existing Fnative-wire/HPAX APIs and existing peer lock/flush/ACK order were checked from pinned source. OtherTask6/early-final/cancel/RST/fullmatrix/load/H3 gates remain open.

All16proposal input hashes/initial byte lengths match;16hashes rechecked unchanged. Proposal SHA256 `89344202718ea3feb9cfc9e3b71897c09ba73eb5041594adfb33b8115dd2723d`. Full design/plan/acceptance/proposal read. No runtime,tests,builds,browser,format,network/dependency/Git mutations or repository edits. Only these two reports written;all commands finished exit0,no live commands,new incidents0. Historical author truncation incident retained,not counted again. Received counter6 root342/orchestration248/prefixTool16/creditTool1;prefixruntime/fixture/Sol0,Astra2/2exhausted unchanged;repair rounds added0.

Root will arrange narrow author draft2 repair. Independent revised SPEC/CODE and actual predecessor closure/local custody remain required before successor entry.
