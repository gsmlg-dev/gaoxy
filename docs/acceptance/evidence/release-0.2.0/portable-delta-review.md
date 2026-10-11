# Portable release fallback incremental independent review

Task: m3_remaining_audit/portable-delta-review. Direct, bounded read-only SPEC then CODE/docs assignment. Worktree `.trees/m3-gateway`, verified HEAD/source `32ec599790ccddb477345a765681f74852e5ffc0`; parent-owned dirty AGENTS/receipt preserved. Only this report written.

**SPEC: PASS. CODE/docs: PASS (static incremental review only). Active actionable findings: none. Full patched builder/runtime qualification: IN PROGRESS / not accepted by this review. Publication: NOT RUN. Hosted run38137347576: BLOCKED_ENV, no steps executed.**

The exact delta from saved initial Dockerfile/build.py changes only the builder image digest to `hexpm/elixir@sha256:abbfaf9699b7a3650810c92268023806217486c26b4da3dc0492a778b22a09bb`, exact `OTP_VERSION=28.5.0.5\n` assertion and corresponding provenance field. The source pin, official Elixir1.18.5 source `dfe6612e546cec6557900e67651f7d21805472ef`, Rust pin, dependency lock checks,486/no-failure/no-skipped requirements, unchanged-source check and both smokes remain unchanged. Registry metadata ties the selected amd64 manifest to `1.19.6-erlang-28.5.0.5-debian-bookworm-20260824-slim`; the builder intentionally compiles the pinned1.18.5 over that image and asserts actual tool versions.

Frozen `source.tar` is still byte-identical to `git archive32ec599`, SHA256 `44418e6dd6190af9b69826f08675310157eb6987831f3b1d6596fa2e37faa86d`. Both tracked hostname test files are byte-identical to that commit. No fixture assertion was widened, skipped or removed. No production/dependency source repair was made.

Root-cause evidence is sound: all three official OTP source snapshot hashes match their receipt; the hostname path maps to HANDSHAKE_FAILURE on28.5 and BAD_CERTIFICATE on28.5.0.2/.5. The original full486/2 failed log hash matches repair-history.json, and both original failures remain FAIL. The patched bounded probe records client hostname_check_failed and peer bad_certificate on OTP28.5.0.5/SSL11.6.0.4. This probe establishes the alert mapping only; it is not full compatibility or artifact acceptance. The repair history accurately remains RUNNING, portable Sol repair1, unsuccessful0 so far, Astra0. No old28.5 PASS is required or claimed.

The dirty release receipt separates canonical local evidence from hostedno-steps, original486/2 and pending patched-profile qualification. AGENTS records the user's no-spending-request boundary without account/settings/permissions changes. Dismissed #97 is neither pursued nor recreated. M4/new source remain outside this delta.

Static download-verifier review passes. It requires exactly archive/build-info/SHA256SUMS, equality to qualified local bytes, two-entry checksum coverage, version/source/counts/check exits, archive+ERTS/application inventory, remote lightweight v0.2.0 tag matching frozen source, five local tagged versions, non-draft GitHub release and exact asset names/sizes. Its PASS is an asset/source verification result after independent qualification of the supplied local directory; its hardcoded qualification text must not be used as substitute for actual offline-runtime evidence. No verifier execution or publication was performed here.

Pending execution checks remain unchanged: final SHA256SUMS must cover both archive and build-info before fresh runtime (current build.py initially writes only archive; worker's explicit finalization remains part of the pipeline). Full unchanged486, builder core3/gateway2, packaged checks, actual fresh Debian `--network none` launch, required libraries/no-Nix ELF and current artifact hash review must pass before final portable acceptance/publication. Support remains Debian bookworm/glibc amd64 with recorded runtime libraries; other profiles and bit-reproducible output are not established.

Reviewer verification: read-only diffs/source inspection, three Python AST parses (no execution), frozen archive equality, saved manifest metadata, source-snapshot/log hashes and unchanged test comparisons all pass. No Docker/Mix/build/live fixtures launched. All commands finished. Historical counters unchanged; this review consumes zero repair rounds and no Astra gate applies.

Reviewed file hashes:

- `.audit/release-0.2.0-portable/context/Dockerfile`: `ecb5ff7403e1ad61c3df829e58cb9944a3f99addfc8cd0f6fa27d770070360b4`

- `.audit/release-0.2.0-portable/context/build.py`: `d2d59e1077f960f583bfa5e37c4cfa6bbbd73815281847564d5a52e1e5f40eec`

- `.audit/release-0.2.0-portable/context/runtime.py`: `2c0af230efca7df6a4c98e2754164940e99dc4fc1b08bc12366c35d858b8e373`

- `.audit/release-0.2.0-portable/evidence/tls-root-cause.json`: `714e9d6d99f07766dc9b2d17777e2af2caec92e2f253c9324c0d8fcc80a38583`

- `.audit/release-0.2.0-portable/evidence/repair-history.json`: `698bd514e6145fd94aefd9bac7896111e1de4d851867781d20ca46803d1456da`

- `.audit/release-0.2.0-portable/evidence/builder-manifest-patched.json`: `abbfaf9699b7a3650810c92268023806217486c26b4da3dc0492a778b22a09bb`

- `.audit/release-0.2.0-portable/evidence/hostname-probe-patched.log`: `33c83c62b855ff8ee0ce80774f5fa9dd7d08ffac835271d1e2036637e8b7ec88`

- `.audit/release-0.2.0-publication/verify-download.py`: `697327f18df28b8921621579ba4f048571e7630e40e8ed722d6732b213a8478d`

- `AGENTS.md`: `285ddeaa4619cadc722cb2bc71e543c92d0d388c3591aa2f311fa9c343a1bdbd`

- `docs/acceptance/release-0.2.0.md`: `45feef3c06a148a13adfd2db638b3f803e22cd4006be9821e21b629e0480fe77`
