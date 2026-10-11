# M3 H1/H2 final independent review

PASS specification, code and scoped evidence review. No actionable findings. Task `m3_remaining_audit`, direct independent read-only review in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`; parent-supplied baseline `85c2284a035e0b4ecbf577279eee01142702b5a3`. Parent executed all runtimes; reviewer independently parsed their raw records and checked hashes.

## H1 fresh evidence and analyzer repair

`h1-baseline-postb21-current2` executes exactly B01–B20:20/0, actualexit0, zero skips/exclusions. `h1-b21-current2` executes exactly B21:1/0, actualexit0. Both freeze1143 files without in-run changes. The format-check receipt records actualexit0. B21 binds two accepted ClientHellos, C2 third-connection rejection/no third accept, original completion pending2 then unconfirmed2, retirement pending then unconfirmed, public aborted2,15 actor joins,8 retained controls,3 occupied launched attempts and zero refunds. Accounting remains BLOCKED_INPUT; native frontier remains UNESTABLISHED and activation DISABLED.

Each saved tree contains69 raw files and three separately saved fixture sources. Current baseline owns63 runtime files; its B21three files and three auxiliary documents are historical. Current B21 owns six runtime files;60 baseline files and three auxiliaries are historical. Current JSONL rows are127 baseline and4 B21, all with the correct run origin and bounded lines. Every saved hash, current raw result and run identity matches. The coarse analyzer `current_artifacts` field includes non-Bxx auxiliary documents; the explicit clarification and these counts prevent treating them as fresh runtime evidence.

Original analyzer77b6c24e and its red failure are preserved. Its B21 branch incorrectly checked retained historical JSONL against B21 cardinality. Current93045fc2 narrows those checks to B21 files and permits existing saved files only when their bytes are identical; analysis output stays exclusive. Baseline analysis still refers correctly to the original analyzer. Independently verified saved evidence passes without rewriting it or rerunning a VM.

`h1-b21-gate-relative-negative1` records actualexit1/registered0/BLOCKED_TLS95_GATE, with no runtime case or summary. The live69-file raw tree remains byte-identical to saved B21 evidence. Later documentation edits to the qualification plan and MANAGED_README are disclosed; runtime before/after snapshots remain equal and fixture bytes remain pinned.

## H2 normal eight

`h2-functional-supplement-current1` records actualexit0/34.561s under600s, exact8 cases, TLS4/h2c4, failed0/skipped0 and peer_shutdowns8. ExUnitcounts0 are not used as acceptance. Four parser cases independently record reset1 and exact invalid_headers_transition; abort/deadline cases record reset8 and exact aborted/request_timeout. Early sentinel wire byte `r` is sent and ACKed before malformed trailers; late reset and pending completion precede first read. Manual original completions confirm twice; follow completion remains unsupported_redirect.

All recorded operations use fixed D10s/C15s and finish within the same deadline; command/event/line caps hold. All peers exit0/PortDOWNnormal with zero cleanup errors/forced cleanup. TLS uses verify_peer and the exact disposable CA, negotiated ALPNh2, and removed temporary certificate directories. Raw cases/results equal saved JSON; all10 saved artifact hashes pass.

Wrapper primary/postidentity are bothOK. The1256 manifest rows match raw before/after identities and current bytes. Before589 loaded rows remain unchanged among after643; before15 mapped files remain unchanged among after16. Added rows are independently checked against disk SHA and loaded/disk MD5. The1145 collector freeze is equal before/after; later MANAGED_README documentation drift is disclosed separately.

## Five expected negatives

| Probe | Actual VM exit | Preserved fixture status | Verified failure-path oracle |
| --- | --- | --- | --- |
| prerepair-acquired-manual | 1 | FAIL | Acquisition barrier/injected primary; no cancellation or response recovery; peer resets0. |
| prerepair-acquired-follow | 1 | FAIL | Same barrier/injected primary; no cancellation or recovery; peer resets0. |
| repair1-acquired-manual | 1 | FAIL | Original abort_and_await:ok; unused first response recovered; stream DOWN:noproc retained; reset8. |
| repair1-acquired-follow | 1 | FAIL | Owned controller abort:ok; unused first response recovered; stream DOWN:normal; reset8. |
| repair1-lost-alias-follow | 1 | BLOCKED_HANDOFF | Real original Task.await2000ms timeout/failed alias retained; public abort:ok; no second await; explicit unresolved-response-ownership block; reset8. |

All five logs match receipt hashes,1145 collector snapshots are stable, and all1285 parent inputs equal before/after/raw identity and current files. Their saved cases/results and15 artifact hashes match. Exact eval argv only prints public System.pid before requiring the unchanged wrapper. Actual parent wait/collector exit is captured before result interpretation; observed VM process groups are empty afterward, VM `/proc` paths absent and owned-peer survivor lists empty. Fixture peer_shutdownfalse/summarypeer_shutdowns0 are preserved, not relabeled as normal eight-case success. Every peer separately exits0/PortDOWNnormal and records zero live threads.

The negative analyzer2ec02639 and runnera9aa3ded pass AST/source review. Their emitted analysis preserves fourFAIL/oneBLOCKED_HANDOFF and adds zero normal-suite cases. Wrapper postidentity/outcome and loaded-after remain NOT RUN for all five because System.halt1 bypasses them.

## Fresh native profile and limits

`h2-native-profile-after1` records actualexit0/33.022s under90s with stable1145/no peers. Raw after JSON exactly equals the before extracted profile. Reviewer rehashed254 bound regular files and checked113 ELF paths plus483 unique NAR entries with actual hashes equal registered values. Reviewer did not rerun NAR collection. This establishes identity only, not native lifetime/reclamation.

Validation consisted of static reads, Python AST parsing and independent Python reconstruction of receipts/logs/oracles/identity/files/JSONL hashes. All checks above passed; no VM, Mix, test, peer, network, Git or builder was run by reviewer. All own commands finished synchronously. Only new review reports were written. Counters unchanged: H1 Sol3/unsuccessful2/Astra1; H2 Sol1/unsuccessful0/Astra0; TLS Sol4/unsuccessful2/Astra2. No decision or actionable finding remains in this assigned review.

Qualification is limited to H1 selected functional fixtures, H2 selected public functional8 and these expected failure paths. Managed activation/native accounting/frontier/soaks/fullM3/M4/hostedCI/publication/deployment/production acceptance remain unqualified. The companion JSON contains exact reference hashes and actual negative operations.
