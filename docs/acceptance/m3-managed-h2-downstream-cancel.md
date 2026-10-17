## Current downstream-cancellation qualification — 2026-10-18

The bounded four-case native-H2 cancellation slice has **PASS local runtime qualification** on entry commit `e40284971ac1df030ef8bcb46e07b0b3838a3c53`. Final documentation review, index/commit custody and the local commit are still pending; this checkpoint does not claim local closure. Evidence: `docs/acceptance/evidence/m3/managed-h2-downstream-cancel/1792264566506557815`. The source candidate4 hash is `202ec7ed68b3c814e5e36171834cef153eaffe8244454f94f1228adb7a582405`; inventory3 is `9ba4963e98b0f5367d02d718062dbd1a86f029aae68690f0193a5e4c0a610dc0`. Actual runtime bindings are402 source files,11 entry documents and11 installed dependency files. Installed HTTP packages remain0.21.10; no dependency or production edit was needed here.

All four fixed/group × h2c/TLS-H2 upstream cases passed with native-H2 downstream. The original stream1 and live stream3 sibling share the actual downstream socket and upstream connection. After exact sibling prefix receipt, the sole native RST(CANCEL) produced actual upstream reset8 at exhausted upload credit. The original worker died `killed`, public completion succeeded and guardian died `normal`; original pins were removed and exact resource/accounting holds changed2→1 before sibling suffix/trailers were released. The original24 cases/helpers remain byte-identical. Socket submission does not establish parsed or queued upload trailers.

| Executed gate | Actual result |
| --- | --- |
| First repaired defining suite |66 tests,0 failures, exit0 |
| Independent source SPEC3→CODE3 |22/24 checks PASS, no unresolved findings |
| Independent implementation SPEC1→CODE1 |26/26 checks PASS, no unresolved findings |
| Fresh strict force compile / seven-path format / syntax |exit0 each; static0 tests |
| Fresh defining / lifecycle / unfiltered Generation traces |66/0,154/0,188/0; exit0 each |
| Python startup / isolated Core / isolated HTTP |11 actual methods successful; Core1/0 and HTTP2/0 |
| Group browser |two nativeH1/H2→TLS-H2 rows PASS; four new root image opens |

The three fresh ExUnit batches are408 overlapping invocations, not unique tests. First66, Python11, consumer counts and browser rows are separate. Nonbrowser audit3 SHA256 `f9489e386d959ef2a7dc09c91d0e1d0b5b7632bad72e5f4a2bf0eef693742150` verifies all nine final commands and exact case traces. Browser audit3 SHA256 `12ce1c5f45ea42072a7a404ad30e0409c3fa65882e211159d32ab900b03fda55` verifies54 artifacts,204 loaded bindings (194 file-BEAM plus10 inline source/module-MD5 records),12 named actors exit0/nonforced and the four root image inspections. All outer commands joined without forced cleanup or residue. Adopted nonbrowser child waits decode to {-10: 17, 0: 10}; browser adopted waits decode to {-10: 2, 0: 10}. These genuine reclaimed waits include signal10 and must not be described as all child exits0. Browser coverage is separate from the four temporal cancellation proofs.

Historical first1 FAIL66/4/exit2 and first2 FAIL66/2/exit2 remain immutable. Sol repair1 corrected the exact H2 before/after-header phase contract; Sol repair2 strictly asserts fixed0/group1 setup requests plus exactly two application requests, hence final totals fixed2/group3. Neither weakens assertions or changes deadlines. Counter12 (`b7a8d5949a4370df46ea19b3c23fadb965fc17f8ddf75e9825a93475e7503457`) preserves root469/orchestration374, downstream tooling27/runtime failed-green2/fixture2/Sol2 and all inherited categories. Astra2/2 remains exhausted; counters are distinct categories, not additive totals.

The original text and preparation checklists below are preserved historical checkpoints. Exact eleven-document pre-overlay bytes are archived by `pre-final-document-cohort1.json` (`624912cf72d405e77420e976e5b8659e8061696bfcc985479387799ebec8eacd`). This current overlay governs runtime status; final independent document review and actual commit custody remain pending. WholeTask6/Task5/M3 stay **OPEN**. After actual local closure, automatically implement the prepared managed-H1 eight-row/two-family matrix and finite integration entry. Sole blocked-H1 disconnect, combined slow-peer/queue/peak/sibling qualification and other remaining product gates remain separate. No push, release, deployment, production/Vault/operational-certificate/public-management/account change or disabled E2E activation follows.

## Frozen earlier checkpoints — unchanged

# Managed H2 downstream cancellation acceptance proposal

Status: NOT RUN. Actual entry commit `e40284971ac1df030ef8bcb46e07b0b3838a3c53`, evidence `docs/acceptance/evidence/m3/managed-h2-downstream-cancel/1792264566506557815`. The predecessor early-final-postcommit-custody2.json verifies actual local closure. Preparation baseline ceb3c0c is historical; source feasibility is not runtime acceptance.

## Four temporal cases

| Downstream | Mount | Upstream | Status |
| --- | --- | --- | --- |
| native H2 | fixed | h2c | NOT RUN |
| native H2 | fixed | TLS-H2 | NOT RUN |
| native H2 | single-member group | h2c | NOT RUN |
| native H2 | single-member group | TLS-H2 | NOT RUN |

For EACH row, require all of the following with exact identities and unchanged finite budgets:

- Original native stream1 POST and healthy stream3 GET use the SAME downstream socket; independent peer reports the SAME upstream connection, distinct upstream stream IDs, exactly two requests. SETTINGS ACK initial window1; TLS rows additionally exact same-connection ALPN h2/SNI localhost.
- Socket submission of body `<<0,255>>` and terminal duplicate request trailers first/second, upstream prefix `<<0>>` exact bytes/hash, held_bytes1, stream_window0, positive connection window, credit never released. Do not claim pump parsed, `HTTP.Stream.finish` ran, or upstream trailers were queued. No extra parsed-queue requirement and no dismissed #97 proof.
- Authentic original guardian/worker/completion/original_request/T token/resource/request pins and G token/selection captured; actual worker and guardian monitors installed BEFORE stimulus, both alive. Both-live pending receipts, exact token/pin sets, T count2, Service cleanup2; group inflight2, reserve `2*16_478_862`, exact controls.
- Sibling alone starts status200/content type/declaration response. Callback actually receives exact complete binary prefix with END_STREAM false, proves both-live authentic holds, then emits the SOLE native stream1 RST code8. No test-side abort/Session cancel/upstream reset/credit release/socket close before acceptance.
- Actual independent original-upstream reset code8 carries exact snapshot: total_bytes1, body64 AA==, SHA256(byte0), credit_released false, response_started false. EOF/connection_reset or elapsed non-arrival cannot substitute. Existing peer held trailer/end guards remain strict.
- Before releasing sibling suffix: actual worker DOWN killed, original public completion await5,000 and await0 both ok, guardian DOWN normal; original tokens/request pins absent; exact sibling identities/pins/selection alive and completion pending; T count1 and Service cleanup1; group inflight1/reserve `16_478_862`/exact controls. Process DOWN alone does not establish public cleanup; public cleanup alone does not establish actual remote RST.
- Only after that checkpoint: exact sibling binary suffix plus ordered duplicate x-check response trailers first/second and terminal completion on SAME native stream3. One and only one exact prefix receipt; full status200/body prefix+suffix/trailers/content-type assertions. Existing parser rejects server RST or GOAWAY.
- Then socket close, unchanged F/G clean and close, both completion await0 ok, baseline-only resource holds and zero Service/T/G request accounting, physical upstream termination, exact fixture actor joins, peer requests2/forced0/live0/failedfalse/exit0. No replay or replacement connection inferred from byte totals alone.

## Source and scope review gates

- Only executable diff is `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs`: four new cases and additive keyed/count-aware helpers; original24 cases and singleton helpers exact; F/G/peer/deps/production/deadlines unchanged. Parent confirms against actual entry SHA, not a guessed successor.
- Independent source/document SPEC→CODE and implementation SPEC→CODE review both PASS with findings resolved, followed by fresh required verification. The source chain supports worker killed/guardian normal expectations, but they remain runtime obligations. Any unsupported expectation is flagged before broadening scope.
- H1 disconnect, H1 upstream/full matrix, other cancellation/multi-owner/selectedA/standalone/sustained loads/H3 remain separate. This bounded success does not close Task6, Task5 or M3.

## Required evidence inventory and fresh gates

Root freezes new inventory before runtime, deriving exact commands/scopes from E9 `docs/acceptance/evidence/m3/managed-h2-early-final-exhaustion/1792258318148616262/command-inventory2.json`, rebinding accepted tools by PATH ONLY into actual E10. New names are frozen deliberately; suffix2 is not copied as new custody. Root independently verifies materialized tool bytes. No giant old runner is embedded here.

| Gate | Required result | Current |
| --- | --- | --- |
| First defining trace suite | nonzero actual tests; four named new cases pass | NOT RUN |
| Independent source and implementation SPEC→CODE | resolved findings; exact candidate pins | NOT RUN |
| Fresh strict force compile / seven-path scoped format / syntax | successful exact inventoried commands | NOT RUN |
| Fresh defining / lifecycle / unfiltered Generation trace batches | nonzero actual tests; exact named trace coverage including preserved Store-death checks | NOT RUN |
| Python independent peer startup | all actual 11 required methods executed successfully | NOT RUN |
| Isolated Core / HTTP consumers | actual Core1 and HTTP2 passing checks with isolation | NOT RUN |
| Group browser | both existing rows pass; four fresh root image opens | NOT RUN |
| Final custody/audit | actual source and command counts, exact pins/disk/index/blob bytes, receipts, child waits and actor shutdown | NOT RUN |

Record exact commands, environment/cwd, candidate source identity, start/end, status, actual nonzero test/method counts, exits, finite process joins, child wait conversion and artifact SHA256/size. Record FAIL/BLOCKED/NOT RUN separately from PASS. Do not carry forward historical counts402 or test totals, invent new totals, or sum overlapping batches as unique tests. Preserve predecessor/historical failures immutably; never read/enumerate/hash/stat protected unrelated E4 close-diagnostic files, raw traces/NetLogs/keys. Browser2rows and four image opens are separate from temporal RST evidence.

Cumulative counters inherited unchanged: counter15, root431, orchestration336, earlyTool31, downstreamTool2, Astra2/2 exhausted. No new Astra; ordinary authorized Sol diagnosis/repair preserves assertions and counters. No push, publication, deployment, production/certificates, Vault, public management, E2E enablement, account setting changes, or new upstream workaround. No upstream bug was found in this source-only preparation.

## Precise response-phase contract — Sol repair 1

The retained first defining run `downstream-cancel-first1.json` executed 66 tests with 4 failures (actual exit 2, source stable, joined/nonforced). All four new cases failed before the native reset: the initial helper incorrectly required the sibling submitted URL after its response prefix. Existing production `session.ex` clears that URL on H2 response headers. This is a test phase-contract error, not an established upstream bug.

At capture and all pre-response checkpoints, require `headers === false`, the exact submitted URL and exact binary backing. At the exact sibling prefix checkpoint and the surviving-sibling checkpoint, require that sibling `headers === true` and `submitted_url === nil`; the still-unanswered upload retains `headers === false` and its exact URL/backing. The callback explicitly selects the original sibling guardian, present exactly once. Original identities, pins, selections, request fields, pending completion, worker/guardian liveness, counts, reset snapshot, causal ordering and finite deadlines remain unchanged. No nil-or-URL allowlist is accepted. Original24 and existing helpers remain byte-identical.

The first failure remains immutable. Freeze repaired candidate3/inventory2/audit3 before new suffix2 first/final/browser commands and obtain fresh independent SPEC→CODE source review. No repaired runtime gate is claimed yet.

## Exact fixture setup count — Sol repair 2

The retained repaired first run `downstream-cancel-first2.json` executed66/failed2/exit2, source stable and joined/nonforced. Both fixed new cases passed; both group cases reached the final observed-request count assertion after all causal cancellation/cleanup/sibling checks, then observed3 versus expected2. Group close acceptance was not reached, so group cases remain FAIL. Existing `support/managed_h2_group_fixture.exs:127-156` consumes exactly one real HEAD `/health` request before returning a healthy fixture; fixed setup consumes none. This is a fixture accounting contract error, not a demonstrated upstream bug.

Freeze and strictly assert setup requests: fixed0/group1. Require exactly two additional application requests (the original POST and same-socket GET sibling), hence exact peer totals fixed2/group3 including the known group health HEAD. Final no-extra-request check and unchanged close require the peer's terminal total to equal that exact observed count. A variable baseline cannot mask extra setup traffic: the initial0/1 assertion is mandatory. Same-connection/distinct-stream identities, precise before/after-header phases, original holds/pins/counts, reset8 snapshot, causal worker/public/guardian cleanup, suffix ordering and deadlines all remain unchanged. Preserve both earlier FAIL receipts, original24/helpers, and all source evidence. Candidate4/inventory3/audit4 and suffix3 first/final/browser gates require fresh independent source SPEC→CODE review; runtime after Sol2 NOT RUN.
