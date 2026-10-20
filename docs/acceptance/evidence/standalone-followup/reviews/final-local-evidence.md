# Independent final local evidence audit

Task: review_compiler_ci / final-local-evidence. Direct read-only assignment. Status: DONE / PASS. No actionable evidence inconsistency found. This is local ordinary-scope qualification, separate from hosted-profile, publication, public-consumer and production acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`.
Qualified source: `ba89895887ac8509a091c1444b1699f6b7cd5631`; version0.5.4. Source archive SHA256 `aa310710a9c436a98dd55be82bca5c4324771d6c3e936542f2d2942a03c408b3`; lock SHA256 `9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`. Actual local runtime is Elixir1.18.5/OTP28/ERTS16.4.0.5. Root and all own-app project versions are0.5.4 as established by final-source review.

Aggregate `.audit/standalone-followup/local-qualification.json` SHA256 is exactly `ae0cff22a829532133a3eb33664dac7f0fdb4ed1171b2b05fa14bcfcc3f1ddfa`. Recomputed all7 phase receipt hashes and checked each embedded receipt equals its file, statusPASS, matching source/version/lock. Recomputed all35 command-log hashes; all match and every recorded exit is0. Independently streamed `git archive` for the qualified commit and recomputed its digest; it matches the aggregate and build identity. Current lock bytes match; HEAD remains the qualified commit and the worktree is clean.

## Actual results verified from raw logs and detailed artifacts

- Canonical format, forced strict warnings-as-errors compilation, actionlint and production compilation pass. The helper regressions execute8/6/5/8 tests for test wrapper, repair gate, release smoke and package staging respectively.
- Full repair log identifies the exact qualified SHA. Per-file ExUnit counts sum160, with original unit subset141 and protocol19. No failures, exclusions or skips occur in this gate.
- Standalone/configuration/activation/rollback/lifecycle regression log executes87 HTTP +33 server =120 tests,0 failures. This includes the approved fixed/group recovery and expired-candidate checks.
- Optional consumer executes4 tests/0 failures after strict compile. Raw output includes actual validating localhost peer exchange, unsupportedALPN/wrongCA/wronghostname rejection, directional controls, isolated connections, listener cleanup and rebind. The negative issuer-certificate log is an asserted rejection, not an unexplained protocol failure.
- Isolated source core and HTTP consumers execute1 and3 tests respectively; Phoenix source consumer executes5, all0 failures. These are source-consumer checks; they are not claimed as post-publication public-package checks.
- Browser manifest identifies the qualified commit. Exactly15 expected named checks are present, allPASS; errors empty, process exit0. Source-before equals source-after for all138 recorded files, and every recorded hash matches the current file. LiveView/browser/H1/H2, TLS/name rejection, reload-and-restore and graceful cleanup checks retain their actual identities.
- Five package build commands exit0 and save all5 version0.5.4 tarballs. Inspected each archive's metadata version and compared every archived payload file with its staged source: all match (13/23/41/12/39 files for adapter/core/HTTP/HTTP3/proxy). Staging/building is not package publication.
- Portable core release smoke coversTCP/TLS/UDP startup, traffic, admission barrier, exit and endpoint reuse. Gateway smoke records2 actual H1/H2 upload/response exchanges plus exit/port reuse. H3 smoke's3 named checks allPASS, both child exits0 and ports rebound.
- Packaged native WebSocket reports execute15/15 checks each forH2,h2c,H3 (45 total), allPASS, no unexecuted cases. Each report explicitly uses packaged_release mode, matching qualified source/archive/lock/version identity; source-identity file hash and current release executable hash match. Each records cleanup with exit0 and runtime_down:true. No H2/H3 WebSocket proxy bridge is claimed.
- Ordinary portable suite executes8/0. Separate fragmentedTCP line selector reports8 total/7 excluded, therefore1 executed/0 failures. Its7 intentional exclusions are preserved and never attributed to the repair gate or counted as8 executed.

## Scope and limitations

This audit examines completed existing evidence; the reviewer ran no build/test, dependency mutation, source edit, push or publication command. Only this append-only artifact was created. All reviewer audit/archive commands finished, and no reviewer process remains running. Prior failed baseline/repair/setup evidence and the initial REQUEST_CHANGES review remain untouched.

Remaining required gates: successful exact hosted Linux/macOS compilation/unit jobs, repaired optionalQUIC hosted job, actual source-bound release workflow and tag/artifact/public-consumer verification. The old published-source macOS FAIL is baseline proof and does not substitute for repaired-source PASS. No specialist, production, deployment, operational certificate, Vault, public-management or disabled release-artifactE2E qualification is inferred. Parent retains integration/push authorization and will wait for relevant hosted checks before publication.

Received repair counters remainA Sol2/Astra0 andB Sol2/Astra0; this audit adds0 repair rounds. astra_gate: not applicable. Decisions needed: none. Evidence audit timeUTC: 2026-10-20T18:00:47.587544+00:00.

## Audited phase receipt hashes

- `.audit/standalone-followup/final/checks/receipt.json`: `c9f689daceba6afaa8136bacdc319e4cf711bb2fa3fd98d7dc84e12398cf49e6`
- `.audit/standalone-followup/final/standalone/receipt.json`: `1129d10d40ac53d89f9ef0cc28736b7bb1e770fd5953abac3840b65f39a2dda1`
- `.audit/standalone-followup/final/quic/receipt.json`: `0e2a13b6b3b5946553802415a8cce55bf54484e380ee9fbfab1d33b38102cd25`
- `.audit/standalone-followup/final/core/receipt.json`: `7833485013b9a4b4b232081833e6b460d2c99ed4cb47c6ac88247b2684c6d261`
- `.audit/standalone-followup/final/http/receipt.json`: `787208cdbc0a855a78c08f2f9f4768c3fe11bae4fed2c83458fa3a4a7d337a09`
- `.audit/standalone-followup/final/phoenix/receipt.json`: `b4392da87e70a31a646a3f4bbc185568365e032e5ded329df23ff375cc9ab7de`
- `.audit/standalone-followup/final/build/receipt.json`: `cedcb28f509993c4b8be90838e6579d3c14f4f2518ad39bdbc4073e7eca11f07`

## Audited command-log hashes

- `.audit/standalone-followup/final/checks/runtime.log`: `4a35527b8fa6611dc956569bb3de08ec1820e9d13658cad775dacd1ce7151c02`; exit0
- `.audit/standalone-followup/final/checks/tools.log`: `1e51e7acceebe73aea11bd47e81d4ea48ea746e1154bedb72cd1b0b12d42ef79`; exit0
- `.audit/standalone-followup/final/checks/format.log`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; exit0
- `.audit/standalone-followup/final/checks/compile.log`: `c44e52680598a896497a082e7f1920b81c2bf6f996a3f87028840ba9b19b7ce2`; exit0
- `.audit/standalone-followup/final/checks/test-check-tests.log`: `94934a18bedabecccf7e61399882a7e8cd705548d7b8893301eb0d0bbb121e66`; exit0
- `.audit/standalone-followup/final/checks/test-check-repairs.log`: `62cfbeb2911bb226088bfb0918eb4b05008ea70b20bce854ee2ca8a564bd37a5`; exit0
- `.audit/standalone-followup/final/checks/test-release-smoke.log`: `46885b66d2b1edc46d24ca1ce7772212b8a0fd02ab0ff8d339521c3983127c75`; exit0
- `.audit/standalone-followup/final/checks/test-stage-hex-packages.log`: `c4ff8e194e709b24203cffe20c8a949906202a0af876070e3efe20f55df890ed`; exit0
- `.audit/standalone-followup/final/checks/actionlint.log`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; exit0
- `.audit/standalone-followup/final/checks/repairs.log`: `eaca640315687f9e45fafe3189c9f8f5a5072f7c2b10f1c98e7f24057a7c8ee4`; exit0
- `.audit/standalone-followup/final/checks/portable.log`: `ffe67f701979310ba2ac86fd16477a4e6e94872898f063c15f6542f6419f29ff`; exit0
- `.audit/standalone-followup/final/checks/fragmented-tcp.log`: `59ebb618b27ac9993542e6e096effe72e25e38d57445240723fc044ee9671055`; exit0
- `.audit/standalone-followup/final/standalone/standalone-generation-lifecycle.log`: `06d2fb445a5177ea67ed0a46056d941cde2cce18169112d446d3f57a757bdae3`; exit0
- `.audit/standalone-followup/final/quic/optional-runtime.log`: `4a35527b8fa6611dc956569bb3de08ec1820e9d13658cad775dacd1ce7151c02`; exit0
- `.audit/standalone-followup/final/quic/optional-python.log`: `55ae85cf4bdb38743edbcd53ea68ff36511997ec6c21b1e83d8bebc939bf056b`; exit0
- `.audit/standalone-followup/final/quic/optional-compile.log`: `8b47549f8dcf1f23f790571d89e7317271220e29ecbb123e2b637daaf272ce53`; exit0
- `.audit/standalone-followup/final/quic/optional-consumer.log`: `d82d997739920bf8b57f298c9eab12d346ac6a59ca03165662280a94b26c5bc7`; exit0
- `.audit/standalone-followup/final/core/core-consumer.log`: `eb63646611315d212afbf99a727aadd6d74c6c219ef256bc8f844801f2172a0c`; exit0
- `.audit/standalone-followup/final/http/http-consumer.log`: `0f4f1f0900cc478856429a1517b255aae9e528a228570b6fbbee33f9e0f29c7a`; exit0
- `.audit/standalone-followup/final/phoenix/phoenix-consumer.log`: `ee58a654737b6553602791eda0f1e14eb5c6b84e9603b09847b3eee986880d3e`; exit0
- `.audit/standalone-followup/final/phoenix/browser.log`: `1a9d2d787dfd3ec9b03d5659f4c5a0aca7516fa1e795f0440ccbf37e0dd7cb15`; exit0
- `.audit/standalone-followup/final/build/production-compile.log`: `77f9ae3f6693657f596c949f5a22bccb2753d00c5f4181532f7d8d5b5a3b05d7`; exit0
- `.audit/standalone-followup/final/build/release.log`: `22c64390b10daf37d92c4664522f56d61957473a72f9c874be1a475a1bcf61a4`; exit0
- `.audit/standalone-followup/final/build/stage.log`: `73045fb31e18202bdaa8943b4c64be0c46eb9e84a1cbb6fddb19baf19007bbee`; exit0
- `.audit/standalone-followup/final/build/build-gaoxy_websock_adapter.log`: `024c8536ee01bcb03ffb9995dee09f1cd88034f3b3cbb312f1a48b1480d3daa9`; exit0
- `.audit/standalone-followup/final/build/build-gaoxy.log`: `d4c5c0feb7bd1d0cf28bc340e1e5e501235e6d858a446a273867f3d7e4a4fb4e`; exit0
- `.audit/standalone-followup/final/build/build-gaoxy_http.log`: `9b4719d29c4a60c1ecbe0005a24b435de42bc0c607f7ab3b1614a797d42766df`; exit0
- `.audit/standalone-followup/final/build/build-gaoxy_http3.log`: `22f2078b5882979346902f080d08654d11dafe52ce981eee6de5b90a645727f5`; exit0
- `.audit/standalone-followup/final/build/build-gaoxy_proxy.log`: `693c8a4d467e14a79c5eaa7497fb3a57c37f2c56ffca14587cc0bb77013b1a5d`; exit0
- `.audit/standalone-followup/final/build/core-smoke.log`: `bbe55e3930a33774a4cc3723263bb484031efa4656c666acda5e2ea4d823672b`; exit0
- `.audit/standalone-followup/final/build/gateway-smoke.log`: `b826ff6b473e7b752be0414ae52c5ad14a8b0236b022f11ea7c3dc0dce555bae`; exit0
- `.audit/standalone-followup/final/build/h3-smoke.log`: `34d67fc2d978945aca6344e0afc87e634670a7b9f117128c33dcaf9fb2b6326c`; exit0
- `.audit/standalone-followup/final/build/websocket-h2.log`: `f6b4d06110e7c8f48bb2e4cc1989d36c341d5738b8086313fa3ece8cc5c0cc80`; exit0
- `.audit/standalone-followup/final/build/websocket-h2c.log`: `7fb4ba755919f7a883f7126573e02923703db4b08daed1cc5b3002eb0a42748e`; exit0
- `.audit/standalone-followup/final/build/websocket-h3.log`: `3ec92e95f9c45c9e4525e0d4a87204f61e1ce6203ba63c0423eb26a3ac2ee77e`; exit0

## Additional detailed artifact hashes

- `.audit/standalone-followup/final/phoenix/browser/manifest.json`: `937ee147121c0fa72386a3272f3f8e5b9cef6f09575a4d75b2fbb572a91574ed`
- `.audit/standalone-followup/final/phoenix/browser/results.json`: `88425207d60606ae1670de626731927bc29657ddd0ebc22b28145847900f0c00`
- `.audit/standalone-followup/final/build/source-identity.json`: `c408fdaabde4b5ec0f00915aa041eb260a48a6063bfdff25139c0aaeaad62972`
- `.audit/standalone-followup/final/build/h3/result.json`: `4747d9188c57dfe6dd9ae6be5ede264349d22c710abb63616d7a8bfbb18f4a24`
- `.audit/standalone-followup/final/build/websocket-h2/run-1792519078469225036/report.json`: `356932731ec1df499e915156a4d38d921aa46f203737596cca50bc0bdc154bc1`
- `.audit/standalone-followup/final/build/websocket-h2c/run-1792519081659925149/report.json`: `8a0e35645734c7fdf7ddb07ddf78f137c4577f6ea3b8ae961b6b9ba2009f2e5e`
- `.audit/standalone-followup/final/build/websocket-h3/run-1792519084427465311/report.json`: `011e51e1348a7bf2250256f60c7094e6d003a22ae08a2319fbc2a8fa10c9aad1`
- `.audit/standalone-followup/final/build/gaoxy_websock_adapter-0.5.4.tar`: `f597f7cd598464c6d42715a1879de7926cdb6bde425214bf3694c0d90ca25679`
- `.audit/standalone-followup/final/build/gaoxy-0.5.4.tar`: `724dc3e27a35454afcf4005c09828dc96dda46f4e4f5d94b7ee0b48e3832c984`
- `.audit/standalone-followup/final/build/gaoxy_http-0.5.4.tar`: `fdcdaf90dfb98412d7a03fb1949690cc006c83b61b4fe5a5437c873710d01e79`
- `.audit/standalone-followup/final/build/gaoxy_http3-0.5.4.tar`: `284c25ab39674c7a8eb8ac69b8c0b6d0b30dec65191541ce8f4cd24f072dd604`
- `.audit/standalone-followup/final/build/gaoxy_proxy-0.5.4.tar`: `a8b05ff7b32398b344d3a02bf76525a35af585e2dd61a94644d5d0ada2b242d3`
