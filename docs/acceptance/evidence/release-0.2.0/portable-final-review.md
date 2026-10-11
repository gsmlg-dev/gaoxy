# Portable Astra1 actual qualification independent review

Task: m3_remaining_audit/portable-final-review. Direct bounded read-only SPEC then CODE/evidence assignment. Repository/worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, verified baseline `32ec599790ccddb477345a765681f74852e5ffc0`. Reviewer owns only this new report; parent owns tracked docs/publication and Astra owns portable execution. Concurrent edits are preserved. This report is an immutable snapshot of the first Astra recovery result; later repairs require a new review file.

**SPEC: PASS for the unchanged qualification contract. CODE/evidence: builder PASS; fresh runtime FAIL. Overall artifact acceptance: BLOCKED_VERIFICATION. Publication, deployment, disabled release-artifact E2E activation and M4 runtime acceptance: NOT RUN.**

The static recovery review remains valid: the staged recipe preserves every existing command, assertion and inner deadline. This review inspects actual exported artifacts and recorded execution, without builds, tests, live fixtures or helper re-execution. No full original-M3 or M4 implementation-completion claim is made.

## Actual builder evidence

The Astra1 builder completed with exit0 in671.8837758004665 seconds within the authorized1800-second outer bound. Its full log hash matches the builder receipt. All thirteen distinct check records are present, their exit codes are zero, their recorded hashes match the actual exported logs, and build-info embeds the same checks.json data. Canonical format, strict production compilation, locked dependency retrieval and independent-peer setup are included. Actual toolchain output records Elixir1.18.5, OTP28.5.0.5, ERTS16.4.0.5, Rust/Cargo1.97.1, Python3.11.2, OpenSSL3.0.22 and Debian glibc2.36.

Compatibility log inspection independently confirms four summaries:90/0 core,196/0 HTTP,182/0 proxy and18/0 server, totaling486 executed tests with zero failures. No nonzero skipped/excluded text is present. The actual core-smoke log passes TCP/TLS/UDP startup, traffic, shutdown and UDP reuse with3 transports. The actual gateway-smoke log passes native H1/H2 POST traffic through the dedicated H1 upstream, SIGTERM exit0 and gateway/upstream port reuse with2 exchanges. Compatibility completed in168.490626 seconds under300; core/gateway smokes completed in4.887314/3.733637 seconds under60 each.

The source archive is byte-identical to fresh `git archive` output for frozen32ec599 and matches its recorded SHA256 `44418e6dd6190af9b69826f08675310157eb6987831f3b1d6596fa2e37faa86d`. It contains2396 unique regular files. The unchanged reviewed builder path hashes every archived source file against `/work` after qualification and before packaging; successful completion and build-info record2396 unchanged files. No host dependency/build directory is added to the source archive.

Actual finalized SHA256SUMS has exactly these two entries, both independently verified against exported bytes:

| Asset | SHA256 |
| --- | --- |
| gaoxy-0.2.0-linux-x86_64.tar.gz | 8e3eeb8c91f4a7cf9e5ccb2307f8623451e7872500a42a07cbc5c3d35b99aa16 |
| build-info.json | 7f883b22d34370adbe61327ad0b4a5d1b636a52e74f8a5ec4e9165360acca586 |

Read-only archive inventory finds1405 members, launcher `./bin/gaoxy`, bundled `./erts-16.4.0.5/bin/beam.smp`, start_erl.data `16.4.0.5 0.2.0`, and gaoxy/gaoxy_http/gaoxy_proxy/gaoxy_server version0.2.0 application directories and matching .app versions. This establishes package identity, not fresh-runtime qualification.

## Actual fresh-runtime failure

The runtime wrapper actually started at13:20:15.053222Z and completed at13:26:29.053161Z, elapsed374.0001147519797 seconds, exit1 under the unchanged600-second outer budget. Runtime image construction passed with exit0 in365.986661 seconds. The fresh-runtime stage failed with exit1 in7.836367 seconds. The retained receipt supplies213 seconds remaining to the original launch helper; the failure occurred immediately and was not an exhausted deadline.

Recorded runtime image `sha256:b16ac807d862d7a882cbe02e448c97510b37ad7fa1a235a860d8dd0043bbbeb1` is Linux/amd64 with entrypoint `python3 /tools/runtime.py`. Actual container `0cc89fbbeb6921f59a4dc52bd5ae16265304037eaa630da50edc0b361ea212ec` uses that image, NetworkMode `none`, a read-only bind of the qualified artifact directory and a writable evidence bind. The retained inspection records Runningfalse, ExitCode1, OOMKilledfalse, empty Docker State.Error, start13:26:26.444504033Z and finish13:26:27.222112196Z, a0.777608163-second lifetime. launch.json records removal of that owned container.

The saved host wrapper traceback is `AssertionError` at run_runtime.py line24, `assert live["State"]["Running"], live["State"]`. The inherited helper asserts Running before calling docker logs and removes the container in finally. Consequently container.log is absent and the underlying runtime.py exception/stderr is UNKNOWN. No final inspection, ELF-dependencies receipt, runtime-checks receipt or runtime-result exists. Packaged ELF dependency acceptance and packaged core/gateway smoke acceptance are NOT RUN or unconfirmed; they cannot be inferred from builder success, artifact checksums or image-build success.

The actionable finding is the actual runtime exit1 plus the missing stderr needed to diagnose it. Preserve the failed receipts, capture exact diagnostics before cleanup in the next authorized repair, and require the original fresh-runtime checks to pass. This report performs no fix or retry and introduces no replacement gate. Pre-publication helper/notes and evidence collection have not been accepted or executed by this reviewer; current missing runtime receipts prevent their qualification checks from passing. No portable runtime support profile is established by this attempt. The intended profile remains Debian bookworm/glibc Linux x86_64; broader OS/architecture/libc and reproducibility claims remain unqualified.

## Preserved outcomes, counters and ownership

The original OTP28.5 compatibility486/2 failure remains FAIL and its log hash matches repair-history. Both Sol repairs remain actual exit124: repair1 at1800s, repair2 under539s with542.008823s including cancellation. Successful Astra builder evidence does not overwrite these results. Portable cumulative counters are Sol2/unsuccessful2 and Astra1 overall unsuccessful because runtime failed. The historical legacy repair-history Astra0 is the pre-recovery record; actual Astra1 receipts separately identify this recovery. This Sol reviewer performs zero repairs and no escalation. Parent plans a separately owned ordinary Solrepair3; it is NOT RUN by this review and does not change this snapshot.

Hosted run38137347576 remains BLOCKED_ENV, with no steps executed and source32ec599. No account/settings/permission changes or quota requests were made. Dismissed http_fetch#97 was not queried, pursued or replaced. Production deployment/data, certificates, management endpoints, Vault and E2E restrictions remain outside this work.

All reviewer read-only commands finished synchronously. No reviewer process, VM, container or live fixture was launched. Actual Astra wrapper commands have recorded completion, and launch.json confirms owned-container removal. Parent/Astra shutdown ownership remains with those writers; reviewer did not manipulate their processes. Only this report is changed by the reviewer. No new product decision is needed; diagnosis and repair are parent-routed under existing authorization.

## Evidence hashes

Paths below are relative to `.audit/release-0.2.0-portable/`.

| Evidence | SHA256 |
| --- | --- |
| evidence/astra1-builder.json | 0ce6823306d94f15cfd098c3ec65ea89a3af1af1737f7d0c27a151260d70b924 |
| evidence/docker-build-astra1.log | 69d787139cc32222a4f13ccaee0ae947bdc7bb20b12ae36e0e60b0cb2cd2896c |
| artifacts/evidence/checks.json | 0b18e99d2041bd60f767104d9b9719a55450fd914f4a73801267f97170f27042 |
| artifacts/SHA256SUMS | a40395740ed8c9646312e966c913079847bfc02ff0de24ce44462ce76cfa5c18 |
| evidence/astra1-runtime.json | 2d5eeca7aefdad80c25d0c01046d66115675a7deb1779eada457fc566dfc8e09 |
| evidence/astra1-runtime-qualification.log | c72b6574c67478b0f0c98c3683fe715b7633807a700fa6400e3cec318f26ffdd |
| evidence/runtime-qualification-stages.json | 637c299fe1a89bb5fa4b40ace90cccfff98d6a7187eb0dc3e148e0efd7b31e0d |
| evidence/runtime-image-inspect.json | a6561df3654e236f53edfc79ef90708d9cf833f138fdfd8e90df997aac55a09c |
| evidence/fresh-runtime/launch.json | 55595ef6321c0b16351e3e8e7440a9df140b324c75271db0b976e75cd529638e |
| evidence/fresh-runtime/container-inspect-live.json | 8cf0ba9c3008a1218f6238c75e4a1faac74cb57d698d816cdd1afc7ab0a84ff9 |
| evidence/fresh-runtime-run.log | 5c8efdaef7423c497a1aafdfbb765d753ce7cb8f84e69b431a7608a4886e830a |
| evidence/docker-build-initial.log | cebf6225fa0513ce9f14e622ad3f2d152aafe8c966cb78f742e65f75a0ea0ca9 |
| evidence/docker-build-repair1.log | ce7cdf2d61431d605364594b9116b1f98bfd957a87851351d59d9775780159f9 |
| evidence/docker-build-repair2.log | 1268bc8a412c5acbbea543a40c3525252da4654c087b75c610e23128ccb4c82c |

Verification used saved-output inspection and read-only Python byte/hash, archive inventory and summary checks; no product check was re-executed. All thirteen build-log hashes, asset hashes, source-archive equality, exact compatibility summaries, inventory and runtime receipt identities/results passed these evidence-consistency checks. The acceptance verdict remains builder PASS / runtime FAIL / artifact BLOCKED_VERIFICATION.
