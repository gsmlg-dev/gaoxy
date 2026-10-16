# Browser lifecycle CODE1

PASS. DONE, direct independent actual-source CODE review; no actionable findings. Fresh browser qualification may start for this exact host3/runner4 pair. This verdict makes no runtime acceptance claim.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; archived baseline `58307a7084298db309a93697b9102b2cc4c87eda` (no Git commands). Host3 SHA256 `21280c6be63e9bef1956fa5fb30002896a7bd25e36583d2f8af1ec3f340b7778`; runner4 SHA256 `eed9867759952b77a2d53a21e0fd717af08281cc8c416483232697ad3d8c51e6`.

Full custody equality is exact: runner compares the entire session_custody event with the explicit event discriminator plus complete request-clean custody payload. No custody fields are discarded. Actual request cleanup, Session normal join and H2 request-worker normal join precede authorization. Host rejects unclean/repeated authorization, requires the real connection alive/unjoined and H2 writer alive/unjoined, then acknowledges; runner checks mode and captured connection identity before requesting graceful Chrome close.

Pinned ThousandIsland Handler416-421 returns exactly `{:shutdown, :peer_closed}` for the matching tcp_closed/ssl_closed socket; terminate495-498 invokes Gaoxy handle_close, whose H2 close sends writer stop. Host accepts this reason only for the authorized exact connection monitor/PID. H1 uses its native connection monitor; H2 uses the distinct connection monitor. Early/wrong-reason connection DOWN fails. Writer exact normal DOWN requires the authorized phase; early writer DOWN fails. H2 request worker and Session may join normal before authorization. All joined flags have exact monitor/PID/reason provenance; join helper checks actual death/reference monitor or receives the exact DOWN itself.

Real service/Gate zero checks, actual connection/writer/worker/Session joins, normal fixture actor shutdown, transport zero-resource cleanup, input helper join and source identity remain. Complete raw-peer framing/sendall/HEAD+GET and worker joins remain strict; idle reset is allowed only after completed response with no partial input, while parsing/send failures fail. CDP/TLS/ALPN/DOM/visibility/screenshot,95 accounting assertions, normal Chrome exit0/no signal, profile removal and normal actor/reader/group joins remain. Forced or nonzero cleanup cannot qualify as PASS.

Verified complete original host1->host2 and runner2->runner3 differences equal archived full diffs. Host2->host3 contains only the two reviewed writer checks; runner3->runner4 only changes host filename. Actual SPEC2 PASS and prior SPEC1 FAIL hashes verified/preserved. No production/source95 constructor checkpoint changes or reopening.

Historical BrowserGREEN1 remains FAIL (H2 executed1; H1 NOT RUN; forced cleanup). Parent reports consumer2/0 joined PASS; this does not establish browser acceptance. Fresh actual H2+H1 lifecycle verification remains required.

Verification was source reads/hash, full text diff equality, JSON and Python AST parsing only. No runtime/Mix/browser/tests/builds/network/Git or repository/evidence edits. Only assigned two `/tmp` reports written. All own commands finished synchronously; no background process started or other process touched.

Counters preserved: group36/root43/stage6 failed GREENs/Astra2of2 exhausted; review adds0 repairs and0 failed GREENs. No escalation or design decision required. Companion JSON binds original/actual sources, dependency lifecycle sources, SPEC artifacts and source-revision receipt hashes.
