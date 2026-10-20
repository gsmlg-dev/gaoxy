# Independent ordinary TCP segmentation fixture review

Task: review_compiler_ci / native-proxy-seams. Direct read-only assignment. Status: DONE / PASS for diagnosis, specification and minimal test correction; no actionable finding.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`. HEAD/baseline: `ba89895887ac8509a091c1444b1699f6b7cd5631`. Sole tracked difference: `apps/gaoxy_http/test/native_proxy_seams_test.exs`, reviewed SHA256 `b49dabaffdd2add555eee811432bc6677039a24a3dc73c947411b57eaeb6d0f2`. Previous ba898958 evidence remains bound to its actual source.

## Diagnosis

Hosted metadata/raw log identify run39470756873 attempt1, unit job118793892338, sourceba898958, macos-15-intel / Elixir1.20.1 / OTP29.0.2. The existing native_proxy_seams file executes20/21 passing. The failing “finish emits ordered duplicate trailers and exactly one terminator” assertion receives the exact response header plus `2\r\nhi\r\n`, without the final trailer block, from recv(client,0,100). This is an executed ordinary test failure, not setup or specialist evidence.

Traced Response.send_chunked/3 through send_head/4 and Exchange.send_bytes, Response.chunk/2 through a separate Exchange.send_bytes, and Response.finish/2 through another send of zero-chunk/trailers/finalCRLF. The passive raw binaryTCP fixture does not promise that length0 receive coalesces these sends. Successful sender completion does not impose receiver chunk boundaries. The actual hosted prefix therefore exposes the test's receive assumption; it does not establish absent renderer trailers.

The retained socket-proof118 script/log uses real loopbackTCP: a length0 read receives that hosted prefix before trailers are released, so the old suffix assertion fails. A second connection uses an exact-length read, releases the trailer write under explicit message synchronization, receives all expected bytes and confirms no extra bytes. Monitor/messages and finite waits replace no assertion; no arbitrary sleep occurs. Script/log hashes match socket-proof118.json and actual exit0. This is a transport-semantics proof, not a claim that Linux deterministically reproduced the original renderer test failure.

## Minimal fix and assertions

The fix at native_proxy_seams_test.exs:144-150 defines the full expected response wire and calls recv(client,byte_size(expected),100), asserting pinned exact equality. This preserves ordered duplicate trailers, chunk framing and the terminalCRLF while additionally validating exact status/header bytes. The100ms receive timeout is unchanged and applies to the receive request; there is no manual retry loop or deadline renewal. Repeated Response.finish(next) and final recv(client,0,5) timeout assertions remain unchanged, preserving exactly-one-terminator/idempotence checks. No sleeps, skips, flushing, product changes or timeout enlargement.

All existing test declarations/parameterization remain unchanged (19 literal declarations produce21 executed cases). Manifest remains21 for this file,141 unit and160 all. No production module, dependency, compiler policy, matrix, certificate assertion, other test assertion or specialist scope changes. Exact-length receive is the narrow appropriate correction for this finite known wire response.

## Completed evidence

Initial verification.json is retained: local1.18 executes21/0 and strict compile exit0, then format exit1. That receipt binds pre-format source96838a2f..., so it is not substituted for final-source evidence.

At review, unique attempt2/verification.json contains5 completed checks, each bound to the reviewed final file hash and baselineba898958. Recomputed every log hash; all match, all exits0:

- Local Elixir1.18.5 / OTP28:21 tests/0 failures, strict warnings-as-errors compile, scoped canonical format.
- Local Elixir1.20.1 builtOTP28 / actualOTP28: Result:21 passed, strict warnings-as-errors compile.

These are inspected worker checks, not reviewer reruns. They do not establish a passing exact macOS/OTP29 rerun. Parent must commit this exact fixture source and qualify the resultingSHA before publication. Historical ba898958 failures/receipts remain preserved.

## Subsequent qualification scope

Parent will freshly run checks/standalone/quic/build phases (31 commands) on the next commit and require both hosted strict/unit profiles plus optionalQUIC again. No concrete acceptance gap is identified in retaining the ba898958 core1/HTTP3/Phoenix5/browser15 receipts with explicit equivalence evidence: the sole source change is this unrelated existing test, while all product/browser/source-consumer fixture bytes remain identical. Those receipts must keep their actual ba898958 identities and must not be described as executions on the newSHA. Actual final public0.5.4 package consumers will still execute after publication. Final source/version/package availability and expected_sha release guards remain required.

Fresh reviewer operations: read-only Git/status/diff/source inspection, source/manifest/test-declaration checks, raw hosted/proof/worker evidence review, SHA256 checks, scoped git diff --check exit0. No implementation edit, build/test rerun or shared dependency mutation. All reviewer commands finished; only this new artifact was created.

Prior counters remainA Sol2/Astra0 andB Sol2/Astra0. The new fixture slice's author counter was not supplied; its initial format failure/correction remains explicitly retained. Reviewer adds0 repair rounds; astra_gate not applicable. No product decision needed. Remaining limits: fresh committed-source qualification and required hosted reruns.

Audit timeUTC: 2026-10-20T18:11:59.560864+00:00.

## Evidence SHA256

- `apps/gaoxy_http/test/native_proxy_seams_test.exs`: `b49dabaffdd2add555eee811432bc6677039a24a3dc73c947411b57eaeb6d0f2`
- `.audit/standalone-followup/hosted/mac-unit-failure/metadata.json`: `e6efbcef2ed91450777e13f8eeace7faeff6999e2988604a993e0f31f5e82fec`
- `.audit/standalone-followup/hosted/mac-unit-failure/failed.log`: `b1274e53fdf15e995fbdb427db60cfa0da51adea963d86465e6814e2ae2efdcf`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/socket-proof.exs`: `10884a49e066f03dfed6c0aa64951720f1b21600649d101f5fc3ef2cfeac350f`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/socket-proof118.json`: `88a82aa5794e08e5adb909f4b75c0c435667ea48a77309d4c69fae04ade0dd69`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/socket-proof118.log`: `bc7aeaa503364e0d81c3c73e537a80dca6e8625dcd698ccc7fd0e930662bf7be`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/verification.json`: `9e682eeac5fc13ab48900310f11dd9cd1b18b82ef12f57d667906fc8c54ac19b`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/attempt2/verification.json`: `f0cf9009c02b6c24a2e0b287f1a64710ff1d114d3b55c796dd307915f5afeb3d`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/attempt2/118-unit.log`: `89a2acc735efe8ef0d3df98545ef88eea832b57e380704cb7513a29ee00f98b2`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/attempt2/118-compile.log`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/attempt2/118-format.log`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/attempt2/120-unit.log`: `873be9960f35f5f1e7b979e1fd65b264baa00adde27a9f5e75d9fc38186c328b`
- `.audit/standalone-followup/native-proxy-seams-segmentation-1/attempt2/120-compile.log`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`

## Parent commit observed at review completion

The parent committed the reviewed fixture while this report was finalized. Current HEAD `d5e0a6c50fdaa5a3cfbff548069005029c41960e` is tracked-clean. Independently verified `git diff --name-only ba898958 d5e0a6c50fdaa5a3cfbff548069005029c41960e` contains exactly the one reviewed test file and its hash remains b49dabaffdd2add555eee811432bc6677039a24a3dc73c947411b57eaeb6d0f2. Thus the source verdict applies to that committed fixture without changing any prior evidence identity. Fresh qualification remains pending on this newSHA.
