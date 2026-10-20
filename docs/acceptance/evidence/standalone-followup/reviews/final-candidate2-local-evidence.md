# Independent candidate2 local evidence audit

Task: review_compiler_ci / final-candidate2-local-evidence. Direct read-only assignment. Status: DONE / PASS; no actionable finding or concrete local integration-readiness gap. Candidate can advance through the parent's authorized local integration/push workflow. Publication remains gated on required hosted results and source-bound release validation.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/standalone-ci-followup`.
Candidate: `d5e0a6c50fdaa5a3cfbff548069005029c41960e`, version0.5.4; tracked-clean. Previous candidate: `ba89895887ac8509a091c1444b1699f6b7cd5631`.
Aggregate SHA256: `d6c8cf32ba14b2e0d7db4843a3566ffb10ff6596ced20950e6bade83e3f8d10a`. The aggregate has exactly4 fresh phase receipts and31 completed commands. Recomputed every phase receipt digest and compared embedded/file receipts; all agree, statusPASS, exact candidateSHA/version/lock. Recomputed all31 raw command-log hashes; all match and every recorded command exit is0.

Independently streamed `git archive` for the candidate and obtained `0090a2ec744c11f7caa7e48960f927b5ba46cd68f653632ca2101c30a4e4e9c1`, matching aggregate and build identity. Current lock hash is `9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`, unchanged and matching all fresh phase receipts. HEAD/current source remained unchanged throughout this audit.

## Fresh relevant results

The checks phase records actual Elixir1.18.5/OTP28 runtime, canonical format, forced warnings-as-errors compile, actionlint and wrapper/gate/smoke/package helper tests (8/6/5/8), all exit0. Raw repair output identifies the exact candidateSHA and executes160 tests with0 failures/exclusions/skips; per-file counts retain the141 unit subset, including all21 native_proxy_seams cases, and19 protocol cases. Raw standalone output executes87 HTTP +33 server =120 tests with0 failures. Ordinary portable checks execute8/0; the separate fragmentedTCP selector executes1/0 with7 intentional exclusions (8 reported), distinct from the unexcluded repair gate.

OptionalQUIC strict compile and actual peer consumer complete4/0. Product/protocol/certificate/assertion checks retain their previously reviewed scope. This local Linux result is not a substitute for the required hosted optional job or exact macOS profile.

Production forced strict compile, standalone release, staging and all5 package builds exit0. Inspected every tarball's metadata version0.5.4 and all payload bytes against its staged source; all match (adapter13/core23/HTTP41/HTTP3-12/proxy39 files). The5 archive digests also match the prior candidate's package bytes, consistent with the sole test-only source delta. This is package build evidence, not publication.

Release smoke logs establish coreTCP/TLS/UDP traffic/cleanup,2 gatewayH1/H2 upload/response exchanges and3 named H3 checks; the H3 result records both child exits0 and rebound ports. Packaged nativeWebSocket reports each execute15/15 passing checks forH2,h2c,H3 (45 total), no unexecuted cases, clean runtime shutdown. Checked each report's packaged_release mode, exact candidateSHA/archive/lock/version identity, source-identity file digest and actual release-executable hash. No proxy bridging or specialist qualification is implied.

## Equivalence and retained evidence

Independently verified `git diff --name-only ba898958 d5e0a6c5` returns exactly `apps/gaoxy_http/test/native_proxy_seams_test.exs`; `git diff --exit-code` excluding that one path exits0. The test hash is the independently approved `b49dabaffdd2add555eee811432bc6677039a24a3dc73c947411b57eaeb6d0f2`. Thus every product/dependency/config/source-consumer/browser fixture byte remains identical. candidate2-equivalence.json accurately describes the delta, fresh required phases and pending public-consumer execution.

The retained aggregate remains byte-identical with SHA256 `ae0cff22a829532133a3eb33664dac7f0fdb4ed1171b2b05fa14bcfcc3f1ddfa`. Recomputed the3 retained core/http/phoenix phase-receipt hashes and all4 command-log hashes; all match the original aggregate and remain bound to ba898958. Actual source-consumer results remain core1/0, HTTP3/0 and Phoenix5/0. Browser manifest/results remain15 named passing checks, no errors, process exit0; all138 source-before/source-after hashes agree and match current files. These executions are retained at their actual priorSHA; they are not claimed as newSHA reruns. Their reuse for unchanged product/fixtures is justified by the exact whole-tree delta check.

The original macOS unit metadata still records sourceba898958, conclusionfailure; its20/21 native_proxy_seams failure remains FAIL and is not overwritten by local green results. The earlier independent fixture review and all prior failures remain untouched. The parent has prepared a clean public-consumer run for the candidate; preparation is not execution, and public-package validation stays NOT RUN pending publication.

## Remaining gates and shutdown

No gap found before authorized local-main fast-forward/push. Both supported hosted strict/unit profiles and repaired hosted optionalQUIC must still pass on this candidate before publication. Source-bound expected_sha release process, fresh tag/package availability, actual release job/artifacts/tag verification and final public-package consumers remain required. No deployment, production data/certificates, public management, Vault changes, disabled release-artifactE2E or excluded specialist work is authorized or inferred.

Reviewer ran only read-only Git/source/archive/JSON/log/hash/tar-payload checks; no Mix/build/test, dependency mutation, source edit, push or publication. All reviewer commands completed and the archive process exited0; only this new append-only report was written. No repair was attempted. Historic counters remain preserved; reviewer adds0 Sol/Astra rounds, astra_gate not applicable. No product decision needed.

Audit timeUTC: 2026-10-20T18:17:56.264682+00:00.

## Audited fresh receipt hashes

- `.audit/standalone-followup/final-candidate2/checks/receipt.json`: `c82691bc12837d3997913e4ff7e881f51c8f24b8856bbe5bb6cc80495b4bb964`
- `.audit/standalone-followup/final-candidate2/standalone/receipt.json`: `c006cd57248d119e7dfebdb356ebf7b7f2c47dfb8d1b2e91b40d06990512d0db`
- `.audit/standalone-followup/final-candidate2/quic/receipt.json`: `4ff90e106c5ae174c8ec9dd3cdfd1fa9f96302a61b3ea4887cdb26c0e0f0226e`
- `.audit/standalone-followup/final-candidate2/build/receipt.json`: `637e6b68fe6e0e8d6270c9396ebb0439b82eac5c4e1d62346e9fae14a3308023`

## Audited fresh log hashes

- `.audit/standalone-followup/final-candidate2/checks/runtime.log`: `4a35527b8fa6611dc956569bb3de08ec1820e9d13658cad775dacd1ce7151c02`; exit0
- `.audit/standalone-followup/final-candidate2/checks/tools.log`: `1e51e7acceebe73aea11bd47e81d4ea48ea746e1154bedb72cd1b0b12d42ef79`; exit0
- `.audit/standalone-followup/final-candidate2/checks/format.log`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; exit0
- `.audit/standalone-followup/final-candidate2/checks/compile.log`: `c44e52680598a896497a082e7f1920b81c2bf6f996a3f87028840ba9b19b7ce2`; exit0
- `.audit/standalone-followup/final-candidate2/checks/test-check-tests.log`: `b088bcdd714b4e7129760b550347f4ec93aea35e64945b6ae58467f3981bcaf4`; exit0
- `.audit/standalone-followup/final-candidate2/checks/test-check-repairs.log`: `62cfbeb2911bb226088bfb0918eb4b05008ea70b20bce854ee2ca8a564bd37a5`; exit0
- `.audit/standalone-followup/final-candidate2/checks/test-release-smoke.log`: `f96363f8d8dff4c4abed7197c63606ead0bd955ea4259bdcb5fb6f47dbe53992`; exit0
- `.audit/standalone-followup/final-candidate2/checks/test-stage-hex-packages.log`: `b5fc39b44d6dbf710c7a5a9b1fa9979f8d9cffb2ae2e9d973ea5ba1a9a4c88af`; exit0
- `.audit/standalone-followup/final-candidate2/checks/actionlint.log`: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`; exit0
- `.audit/standalone-followup/final-candidate2/checks/repairs.log`: `856f46021a24364f055d03376dc683b93bda7ea6a07577de06aa8a16d150bd74`; exit0
- `.audit/standalone-followup/final-candidate2/checks/portable.log`: `ef49181537d0c7da2679f43795acc5237a98b277f7a43d2eee934a93d41726e6`; exit0
- `.audit/standalone-followup/final-candidate2/checks/fragmented-tcp.log`: `2b1547d3af7d1300a0af35fc21d1d7ae9c0ca5ab6563c9dd726a440f4ef6b1f3`; exit0
- `.audit/standalone-followup/final-candidate2/standalone/standalone-generation-lifecycle.log`: `878a41c7d72b93f42e212ec819a1fb585f1c68a0b51033f24de9dab5e4843a75`; exit0
- `.audit/standalone-followup/final-candidate2/quic/optional-runtime.log`: `4a35527b8fa6611dc956569bb3de08ec1820e9d13658cad775dacd1ce7151c02`; exit0
- `.audit/standalone-followup/final-candidate2/quic/optional-python.log`: `55ae85cf4bdb38743edbcd53ea68ff36511997ec6c21b1e83d8bebc939bf056b`; exit0
- `.audit/standalone-followup/final-candidate2/quic/optional-compile.log`: `95c079a5e867d8bb43402f78752daa1f0ac9e7c941157e2f55ee5313dde82317`; exit0
- `.audit/standalone-followup/final-candidate2/quic/optional-consumer.log`: `9751ad1fed365d8fd60d223b8da4bada15fe0734e2bc439277586a83c8e766b4`; exit0
- `.audit/standalone-followup/final-candidate2/build/production-compile.log`: `c44e52680598a896497a082e7f1920b81c2bf6f996a3f87028840ba9b19b7ce2`; exit0
- `.audit/standalone-followup/final-candidate2/build/release.log`: `22c64390b10daf37d92c4664522f56d61957473a72f9c874be1a475a1bcf61a4`; exit0
- `.audit/standalone-followup/final-candidate2/build/stage.log`: `73045fb31e18202bdaa8943b4c64be0c46eb9e84a1cbb6fddb19baf19007bbee`; exit0
- `.audit/standalone-followup/final-candidate2/build/build-gaoxy_websock_adapter.log`: `3b2b53a642d4923dad168a50132ec00e900021d60162fafa95d5c3ea9d8284fa`; exit0
- `.audit/standalone-followup/final-candidate2/build/build-gaoxy.log`: `1c447995bb0e42670ad30d65eef17214edb1ec52cafae7b3b12933e18c034840`; exit0
- `.audit/standalone-followup/final-candidate2/build/build-gaoxy_http.log`: `745e512bf5568fb64b9e21df6d0a7968affaf2d8cbed5faea7bb87533d9b5988`; exit0
- `.audit/standalone-followup/final-candidate2/build/build-gaoxy_http3.log`: `5e63e3382a884efb62d1a9afab0e37aa97ce42e0797e24dd7c79248e81ac06df`; exit0
- `.audit/standalone-followup/final-candidate2/build/build-gaoxy_proxy.log`: `9c060615e883036ba8860516544ac9da1bd75f989699d0894acd25256511bbc5`; exit0
- `.audit/standalone-followup/final-candidate2/build/core-smoke.log`: `61d65d769e2acae76d258fc5865f1397aeead40bcd23e6c6b8f0a021ba03b9e0`; exit0
- `.audit/standalone-followup/final-candidate2/build/gateway-smoke.log`: `b826ff6b473e7b752be0414ae52c5ad14a8b0236b022f11ea7c3dc0dce555bae`; exit0
- `.audit/standalone-followup/final-candidate2/build/h3-smoke.log`: `34d67fc2d978945aca6344e0afc87e634670a7b9f117128c33dcaf9fb2b6326c`; exit0
- `.audit/standalone-followup/final-candidate2/build/websocket-h2.log`: `f6184fc42693860a6d5c62a20edc9619ea43e696d642ba75281fd562872f8ae5`; exit0
- `.audit/standalone-followup/final-candidate2/build/websocket-h2c.log`: `1757a79e651ce2c729d78422d7948552d8cd3fd54d0d27736c813d62ade56d4d`; exit0
- `.audit/standalone-followup/final-candidate2/build/websocket-h3.log`: `344a3cda518da0cc21810e2bc78db4bdd7d3f75426dc4f5c694a6f38e18e5398`; exit0

## Equivalence and retained receipt hashes

- `.audit/standalone-followup/candidate2-equivalence.json`: `74ef3145e0dd74265db1fedb47ca40a5ef57e38af317c4d2377c61179833df4c`
- `.audit/standalone-followup/final/core/receipt.json`: `7833485013b9a4b4b232081833e6b460d2c99ed4cb47c6ac88247b2684c6d261`
- `.audit/standalone-followup/final/http/receipt.json`: `787208cdbc0a855a78c08f2f9f4768c3fe11bae4fed2c83458fa3a4a7d337a09`
- `.audit/standalone-followup/final/phoenix/receipt.json`: `b4392da87e70a31a646a3f4bbc185568365e032e5ded329df23ff375cc9ab7de`

Retained source consumer counts, stated explicitly: core consumer = 1 test, HTTP consumer = 3 tests, Phoenix consumer = 5 tests; each has 0 failures. The HTTP count does not denote an HTTP/3 consumer.
