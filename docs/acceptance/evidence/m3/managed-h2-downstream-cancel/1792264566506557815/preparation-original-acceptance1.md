# Managed H2 downstream cancellation acceptance proposal

Status: NOT RUN. Proposal only; actual successor SHA/E10 PENDING. Parent supplied preparation baseline `ceb3c0c953d930768023da85875a95672876ce39`. The supplied source contract is evidence of feasibility, not runtime acceptance.

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

Cumulative counters inherited unchanged: counter13, root420, orchestration325, earlyTool22, Astra2/2 exhausted. No new Astra; ordinary authorized Sol diagnosis/repair preserves assertions and counters. No push, publication, deployment, production/certificates, Vault, public management, E2E enablement, account setting changes, or new upstream workaround. No upstream bug was found in this source-only preparation.
