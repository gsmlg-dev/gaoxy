# Native-H1 response-write-pressure implementation plan

The bounded native-H1 response-write-pressure slice is **RUNTIME QUALIFIED; final fact/document review and actual local commit/postcommit custody are pending**. Final implementation SPEC1 and CODE1 passed with no remaining findings. The repaired cohort is source candidate14, based on `fb7d0fda2b7c16c42c65579736dc1f643e17d812`, with405 source pins,11 entry-document pins and12 installed dependency pins. This checkpoint claims no actual local commit, custody PASS or slice closure. WholeTask6/Task5/M3 remain **OPEN**.

Candidate14 SHA256: `4e6ad820a380bb4bcf903ad2b7d72ccbb9994e2d5089e98ab94761809f1da1d4`. Runtime cohort SHA256: `2e83693b78cefe89b30ec527d9363f379ba6a185eaf00518156ae6551fe57551`. The only production repair is three native-fixed0 progress lines in `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`, SHA256 `796f5058c7cb2fa23d46f93559caf8eae00836fc8812e6126c306e91455c8776`. The regression file SHA256 is identical across original RED and repaired GREEN: `92430d48c25d3b644a588b61b58fe912eb7a26bfbab1f58163f7a1cef6201fe0`. Entry-document pins identify baseline bytes; synchronized documents require separate final review and actual commit/custody.

Evidence: [completed-response-runtime-cohort1.json](../acceptance/evidence/m3/native-h1-response-pressure/1792276827677035585/completed-response-runtime-cohort1.json), [matrix-final2-observations.json](../acceptance/evidence/m3/native-h1-response-pressure/1792276827677035585/matrix-final2-observations.json) and [completed-response-implementation-spec1.json](../acceptance/evidence/m3/native-h1-response-pressure/1792276827677035585/completed-response-implementation-spec1.json).

## Adopted work and remaining execution

- [x] Preserve actual predecessor H2 local closure, entry source/dependency/document pins, inherited failures/counters and unrelated files.
- [x] Implement the bounded pressure test, necessary opt-in fixture seams and four fixed/group×TCP/TLS-H1 rows with default semantics retained.
- [x] Apply packetization and bounded observer/controller-store corrections without weakening the contract; keep passive diagnostic additions distinct from functional repair.
- [x] Preserve standalone-final1/diagnostic3 failures and complete candidate12 diagnostic-only default16 observation.
- [x] Add the deterministic regression and establish genuine old-production RED1, separately from the preserved syntax setup failure.
- [x] Apply the three-line native-fixed0 progress repair; obtain same-test GREEN1 with normal joins, physical upstream reuse and zero request accounting.
- [x] Run all candidate14 fresh static/pressure/related/default/browser gates below.
- [x] Complete final independent implementation/evidence SPEC1 with PASS.
- [x] Complete final independent implementation/evidence CODE1 with PASS and no remaining findings.
- [x] Root authorized installation of exactly the synchronized five canonical/main documents; both main-plan historical suffixes are preserved byte-for-byte.
- [ ] Complete final independent fact/document review and fresh affected verification after findings.
- [ ] Execute actual local conventional commit and record actual postcommit byte custody in E/postcommit-custody1.json. No local closure or commit/custody PASS is claimed.

## Actual repaired-source gates

| Gate | Actual run | Result |
| --- | --- | --- |
| Strict compile | strict-compile10 | PASS; exit0;0 tests |
| Scoped format | scoped-format10 | PASS; exit0;0 tests |
| Repaired regression | completed-response-green1 | PASS;1/0;exit0 |
| Native-H1 pressure | matrix-final2 | PASS;4/0;exit0 |
| Related five-file group | fresh-after-completed-response1 | PASS;52/0;exit0;seed166590/max-cases1 |
| Full standalone defaults | standalone-final2 | PASS;16/0;exit0;no selector |
| Ordinary browser | browser-final2 | PASS;2 rows;exit0;four actual root PNG opens |

Pressure4 overlaps the52. The completed-response regression1 is separate from52 and standalone16. The browser is ordinary compatibility, not controlled slow consumption. Static checks execute0 tests.

## Deterministic regression and narrow production repair

The native downstream can receive every Content-Length byte before the separately consumed upstream end arrives. Passive downstream closure in that window previously returned `enotconn` and could discard a reusable upstream connection. The deterministic old-production regression established genuine RED: actual1 executed/1 failed/exit2, native fixed0 and `enotconn` before the real end was released. RED/GREEN audit2 passed. Formatting13's earlier syntax failure remains a separate setup failure, not this intended RED.

The three-line repair in `Gaoxy.Proxy.HTTP.progress/2` recognizes only an owned native Exchange with `transport == nil` and `response == {:fixed_stream, 0}`. It continues the ordinary bounded pump and retains genuine upstream end/error validation, Session consumption/accounting and existing idle/total deadlines. It does not consume early, retry or introduce a process, public API or deadline. Incomplete fixed, chunked and bodyless states retain their paths. Framed H2/H3 fixed0 still owes END_STREAM and remains excluded.

The unchanged regression then passed GREEN1/0 with exact body receipt, normal original public completion/Session/native joins, next request using the same physical upstream connection and zero request accounting at baseline. No assertion or deadline changed. Candidate12's earlier diagnostic-only default16PASS is distinct from this functional repair.

The test uses independent upstream/native downstream sockets and real HTTP1.Response.chunk. It holds only after final fixed bytes and write accounting, correlates its original Session/completion, uses a same-sender opaque unchanged-state fence, retains only genuine original end events and observes actual socket EOF. It requires positive repaired pump waiting before restoring actual events/resuming the Session. Finite teardown unblocks/restores/resumes owned actors before fixture stop. Shared regression phase5s and separate teardown5s do not extend the fixture original request10s.

The related command executes exactly pressure4 + H1 matrix16 + wire12 + TLS4 + runtime16 =52 with `--seed 166590 --max-cases 1`; regression1 is separate. Standalone executes all16 default cases without selector. Ordinary browser executes group native-H1/H2→TLS-H1 two rows; root opened four actual fresh PNGs. Immutable command receipts in the runtime cohort retain exact commands, source bindings, counts, exits and cleanup outcomes; no old command or measurement is substituted.

## Invariants retained through final verification

Four rows cover fixed/group mounts × upstream TCP/TLS-H1 with native cleartext H1 downstream. Each row uses separate slow and healthy downstream sockets; H1 same-socket multiplexing is not claimed. Two simultaneous upstream application originals have distinct exact connection identities. Fixed health0/group health1 is separate, with exact union-based accepted-connection accounting and no replay.

The finite body is262,145 bytes with SHA256 `c35991ad254f48ff8b02becb9f0cc56581e86a0b477b13e5ebb0030a3b91c848`. Prefix262,144 bytes use valid chunked upstream framing. Withhold the final one-byte chunk and terminal zero chunk. Producer EOF hold preserves the original but cannot substitute for pressure evidence. After consuming the exact bounded response head, the slow client does not read body until explicit release.

Before prefix dispatch, freeze completed-head send identities from actual matching :ok telemetry. Require a different exact Admission send O with actual positive framed bytes B in1..16,384, positive supported native socket send_pend and native TCP send-stack witness. Freeze identical O+B before sibling progress, after healthy completion and immediately before reader release; final records also capture the two-original overlap snapshot. B includes framing and is neither a guaranteed upstream chunk nor16KiB. Both TLS-upstream rows actually observe B=1.

The reader records release and read-entered before body reception; the actual matching send:ok must follow read-entered. Only after O succeeds and prefix consumption completes may the producer release final1+zero. Require the exact complete body/hash and ordinary validated completion. Original accounting follows2→1→0, with an extra intermediate1 checkpoint while O is complete and producer EOF is still held. Preserve exact original pin/reservation conservation and normal owned joins.

Original request10s/native write2s and existing endpoint/cleanup budgets remain unchanged. All observations and active-send waits are clipped to their original effective deadlines. Finite failure cleanup cannot extend a success deadline. No sleeps, selector exclusions, late observations or forced cleanup qualify as success. Use supported socket APIs, bounded public stack MFA/arity frames and the separate Admission state; do not inspect a blocked native owner with sys.get_state or use private dependency processes.

Bounds remain actor mailbox64, event128 with sticky overflow failure,5ms sampler with at most4096 samples, socket send_pend and parser/client wire each at most1MiB, and pending native write at most16,384. Bounded event/observer storage avoids per-event controller-packet/process growth, checks progress boundaries, and checks final completeness after owned joins/detach; failure reclamation preserves ordering. Sampled maxima remain distinct from persistent Service retained_high_water and from total kernel/VM memory.

Service max_bytes16,777,216, per-native worksheet upper149,504 and two-original/two-native combined upper16,322,640 are unchanged. Preserve transport max_resources2/max_pins32/max_request_tokens64/max_owned_payload_bytes4,194,304 and exact H1 reservation/pin conservation; do not copy H2 charges. Success requires normal original guardians, clients, native/fixture/group owners, observer_helpers_live0, peer_forced0 and peer_live0.

## Historical execution and counters

| Historical run/cohort | Actual result | Preserved meaning |
| --- | --- | --- |
| Initial-probe1 / diagnostic-probe1 | FAIL1/1 each | Original packetization predicate and blocked-send diagnostics; no successful sibling/release/cleanup acceptance in those attempts. |
| Corrected initial-probe2 / matrix1 | PASS1/0 / PASS4/0 | Historical adoption/expansion; never substitute these measurements for final source14. |
| fresh1 / diagnostic-fresh1 / diagnostic-fresh2 / diagnostic-fresh3 | FAIL52/1 / FAIL52/4 / PASS52/0 / FAIL52/3 | Preserve mailbox, assertion-message and release failures with original uncertain attribution. |
| Candidate10 matrix2 / fresh-after-store1 | PASS4 / PASS52 | Earlier observer/pressure cohort; overlapping invocations, not56 unique cases. |
| Candidate10 browser-final1 | Ordinary2 rows/four actual root image opens PASS | Default browser compatibility only. |
| standalone-final1 | FAIL: executed1, passed0, failed1, NOT RUN15 of16 | Original failure remains immutable. |
| Candidate11 standalone-connection-matrix-diagnostic3 | FAIL: executed9, passed8, failed1, NOT RUN7 of16, exit1 | Changed accepted upstream connection in group/h1/tcp temporal case; case/driver cleanup also FAIL, distinct from normal collector joins. |
| Candidate12 standalone-native-result-diagnostic4 | Diagnostic-only PASS16/16, cleanup empty | No functional repair; native-result error export was not triggered; intermittent earlier failures remain. |
| Candidate13 format13 / syntax repair / format14 | Setup FAIL / repaired syntax / static PASS | Zero runtime tests; separate from later intended RED. |
| Original completed-response RED / repaired GREEN | RED1/1 exit2 / GREEN1/0 exit0 | Same regression bytes/assertions; actual premature enotconn/fixed0 before genuine end, then repaired normal completion and physical reuse. |

Diagnostic3 peer EOF731µs after final POST send did not establish a5s receive timeout, identify the cancelling owner or prove a dependency defect. All prior failed source/runtime/browser-helper/tooling evidence remains immutable. Later PASS never erases earlier failure or supplies missing causality.

Counter54 SHA256 `609a816066c40cec971dd746a7a360210ca6a4c7cd0c501341259c4e38ccdc86` records Root734/orchestration617/native-pressure tooling139; native Sol7/runtimefailed-green7/productionrepair1/validRED1 and Astra2/2 exhausted. Categories are separate, not additive; all inherited counters and failed evidence remain intact. No further source/runtime repair followed the verified cohort.

Implementation review receipts: [SPEC1](../acceptance/evidence/m3/native-h1-response-pressure/1792276827677035585/completed-response-implementation-spec1.json) and [CODE1](../acceptance/evidence/m3/native-h1-response-pressure/1792276827677035585/completed-response-implementation-code1.json).

## Final review, custody and next slice

Final implementation SPEC1 and CODE1 are PASS with no remaining findings. CODE1 JSON SHA256 is `2f08a8919418091367958a9983d214ae75af50ba45282d0991672aadbcd2d65d`; its Markdown SHA256 is `4f0905f1160e76c54948df8a5b9052641e688b8c7482989e65ff718bb14d86a0`. Final independent fact/document review, fresh affected verification after findings, actual local conventional commit and postcommit byte custody are PENDING/NOT RUN.

Before a later overlay may state DONE LOCALLY, root must execute the local commit, record its actual SHA and create the named `E/postcommit-custody1.json` receipt with the prescribed source/document/dependency/evidence custody. This prospective receipt name is a required final gate, not an existing PASS artifact.

True upstream socket write-pressure, sole synchronously blocked-upload H1 disconnect, native downstream TLS pressure, standalone slow-pressure registry, controlled browser slow consumption, sustained load/composition and other broad Task6/Task5/M3 gates stay OPEN. Advance the separately prepared sole-H1 blocked-upload disconnect design/plan only after actual bounded local closure and fresh adoption/pinning/review. No push, publication/release, deployment, production data/certificates, Vault, public-management, account changes or disabled release-artifact E2E activation follows.
