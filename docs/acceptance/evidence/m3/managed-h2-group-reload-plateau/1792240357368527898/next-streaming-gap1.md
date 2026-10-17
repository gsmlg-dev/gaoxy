# Next bounded managed-H2 streaming gap

Preparation only. Current group reload diagnosis/gates must finish before any next-stage execution. This report inspects source and existing acceptance summaries; it reruns nothing and does not certify the historical receipts anew.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, supplied baseline `e4a7660baa61a792f4245f511b190a0fcfcbf920`.

## Existing coverage versus remaining cases

The required cells are nativeH1→h2c, nativeH1→TLS-H2, nativeH2→h2c and nativeH2→TLS-H2, separately named. Streaming is Task6 under the wider continuing Task5/M3 integration goal.

| Case family | Current source coverage in all4 cells | Remaining distinction |
| --- | --- | --- |
| Exact targets/duplicates/raw gzip/redirect/length/HEAD/204/205/304 | Fixed endpoint814-882 and group endpoint21-79; independent fixed FUNCTIONAL matrix | Refresh relevant gates after change; no duplicate implementation needed |
| Request bytes before producerEOF and genuine original binding | Fixed884-929, group82-151, independent pre-eof-upload1588-1648 | Ordinary preEOF upload already exists; flow-window exhaustion is different |
| Ordered safe duplicate request/response trailers | Fixed977-1009, group82-188; independent controlled trailers/boundaries | Does not establish cancel/earlyfinal while trailers remain unsent behind an exhausted window |
| Incomplete upload earlyfinal/no replay | Fixed931-944, group170-188; independent early-final after an observed prefix with EOFfalse | Existing cases do not establish upstream window exhaustion |
| Concurrent upstream H2 streams and peer-reset healthy sibling | Fixed946-971, group191-222 and independent concurrent cohorts | Peer-originated upstream reset is not downstreamRST during a blocked upload |
| Successful response prefix before upstreamEOF | Functional /stream checks complete bytes; explicit normal temporal assertion not found in bounded inspected suites | Concrete smallest next positive gap |
| Independent slow upload/download credit, sibling progress and deadlines | Partial fixed H1 write/nativeH2 zero-credit and group nativeH1 idle/total/nativeH2 write-timeout tests | No complete positive slow-peer/blocked-upload cancellation matrix established |

Group nativeH1 total-deadline tests already receive a real prefix with upstream END_STREAM withheld before the required timeout. That is useful negative temporal evidence, not a positive successful response-prefix matrix. Existing group nativeH2 zero-credit tests verify actual write timeout/reset, not release-and-complete with live sibling progress.

The accepted fixed independent harness is `integration/http_fetch_contract/managed_h2_fixed_qualification.py`. Its CELLS and FUNCTIONAL/CONCURRENT/CONTROLLED/BOUNDARIES tuples show135 required cases; CONTROLLED is pre-eof-upload/early-final/request-trailers. The current acceptance summary reports135/135 historically, alongside fixed853/0/public63/browser3. Group acceptance reports25 command gates/1752 invocations and browser3 for its bounded activation. These are historical documented counts, not new execution or unique streaming test totals.

Existing `managed_h2_fixed_peer.py` immediately acknowledges every received DATA in its DataReceived handler. A large upload alone therefore does not establish the required exhausted-window/unsent-trailer phase. A later case needs a real bounded upstream credit hold/release and peer-observed barrier.

## Smallest recommended successor

After the current group gate passes, implement **positive response progress before upstream EOF**,8 explicit cases:4 cells×existing fixed endpoint/single-member group mount. Use the Task6 target `apps/gaoxy_proxy/test/upstream_transport_streaming_test.exs`, reuse the existing safe fixtures and extend only the independent peer/client observation needed for an exact prefix receipt.

For each case, send real headers and a bounded nonempty response prefix while the peer holds final DATA/trailers. Require the downstream observer's exact prefix before that release, no premature terminal result, and original public completion pending with authentic request/G/T holds retained. Then release the exact suffix and safe duplicate trailers, require exact full bytes/trailer order and the original completion/cleanup/peer joins. Preserve finite clocks and existing assertions. Do not duplicate existing successful request preEOF coverage or claim completion of Task6.

The following distinct slice should handle upstream credit exhaustion, earlyfinal/cancel with unsent trailers and downstreamRST with a simultaneously progressing H2 sibling. Its deterministic per-stream credit controls need a separate bounded design/review. No production module or dependency change is justified by this preparation.

## Boundaries and unknowns

Task6's H1-upstream cells, Task7 resource/instance/second-owner isolation, selected-A R32/B-available, standalone composition and full eightcell integration remain separate. The inspected group fixture has one member; it cannot establish two-member admission isolation. Task7b still requires both>=600s managed profiles with their fixed offered-load/body/cap/sample/reset/reload/teardown contracts. Neither positive prefix tests nor group plateau satisfy them. Preserve accepted numeric contracts; do not revive or replace the dismissed upstream proof.

This was a bounded inspection, not an exhaustive search of all tests or a historical artifact audit. The umbrella plan has older successor status; current specific group reload evidence controls its active gate. No next-stage implementation or acceptance is claimed.

Two oversized search/read outputs were tool-truncated and promptly disclosed; the first accidentally enumerated historical evidence filenames but read no evidence contents. Both were replaced by exact slices/declarations; no conclusion uses omitted text. A scoped server filename search had normal no-match/exit1. No protected E4 content/hash/stat or prompts were accessed. No repository/evidence/Git changes, tests, build, runtime or browser execution occurred. All own commands finished and no process was started or touched. Sol repair rounds added0; Astra2/2 unchanged. Only the assigned two `/tmp` reports were written. Parent owns cumulative tooling accounting and current diagnosis.
