# Gaoxy v0.3.0 release acceptance

Date: 2026-10-13. **M4 implementation, portable qualification and publication PASS.**
[v0.3.0 is published](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.3.0); all three fresh downloads equal
the independently qualified bytes. Hosted CI remains **BLOCKED_ENV** with zero
executed steps; deployment, production acceptance and release-artifact E2E are
**NOT RUN**.

The immutable annotated tag and artifact source are `4931982cff7b07c8e9f42a5e4561d22854d418bd`.
The final documentation commit follows this source; it does not replace the
tagged artifact. Source archive SHA256:
`eaabb4a16f0f22e81349b8b01440c10342091849a1cd896dd7a217f6d64fd9bd`.
Root lock SHA256:
`aa9220766e1699f5cfa9d8513df95910a613cf2cbba37e8ce977267e3b68d9ab`.

## Final evidence ledger

| Gate | Actual result | Source-bound evidence |
| --- | --- | --- |
| M4 implementation and independent acceptance | PASS; 530/0 scoped tests, Session50, native/Plug/browser47/59/19, standalone16, consumers1/2/2, two complete UP2 66network+2policy executions | [M4 final ledger](m4.md#final-implementation-gate-ledger--2026-10-13) and its independent reviews |
| Source and main integration | PASS; source4931982, committed archive identity, 4207 unchanged regular files, 342 safe directories, 83 changed Elixir paths, seven exact recipes and 288 M4 inputs | [Final identity review](evidence/release-0.3.0/review-final-portable-source-identity-1791862259192884557.json), [main integration](evidence/release-0.3.0/docker-absence-main-integration-1791862109478931070.json) |
| Portable builder | PASS; 757 tests, 0 failures, 0 skipped/excluded; core91+HTTP210+H3128+proxy263+server65; canonical/83-path formatting and strict compile exit0 | [Build3](evidence/release-0.3.0/portable-final-1791863003049561405/evidence/build.json), [builder metadata](evidence/release-0.3.0/portable-final-1791863003049561405/artifacts/build-info.json) |
| Package metadata and checksums | PASS; five apps0.3.0, 1420 safe entries (1335 files/85 directories), both SHA256SUMS entries | [Finalization](evidence/release-0.3.0/portable-final-1791863003049561405/evidence/finalize.json), [actual download verification](evidence/release-0.3.0/publication-1791863800600551728/publication-verification.json) |
| Packaged protocol/runtime | PASS; builder and fresh offline runtime core3/gateway2/H3three exchanges, including data/zero-data and duplicate trailers; finite shutdown and rebind | [Runtime2](evidence/release-0.3.0/portable-final-1791863003049561405/evidence/runtime.json), [actual artifact/runtime review](evidence/release-0.3.0/review-actual-portable-artifact-runtime-1791863376221811603.json) |
| Offline runtime and ELF | PASS; network none, readonly artifacts, all21 ELF with0 missing/Nix dependencies, child exit0, normal rm0 and exact observed owned-container absence | [Parent stages](evidence/release-0.3.0/portable-final-1791863003049561405/evidence/runtime-qualification-stages.json), [independent review](evidence/release-0.3.0/review-actual-portable-artifact-runtime-1791863376221811603.json) |
| Actual artifact/runtime/notes independent review | PASS_ARTIFACT_RUNTIME_AND_NOTES, findings[]; cleared before tag/release | [Final artifact review](evidence/release-0.3.0/review-actual-portable-artifact-runtime-1791863376221811603.json); notes SHA256753c469174ef398b25655a495a77fac52b7eb8bae1e36be91a47d70599462729 |
| Hosted CI | BLOCKED_ENV; exact4931982 has3 runs/10 jobs, runner0/steps[], test/build exits NOT RUN(null) | [Hosted audit](evidence/release-0.3.0/hosted-status-4931982-1791862228293.json); no workflow dispatch or account/settings changes |
| Immutable tag and GitHub publication | PASS; annotated v0.3.0 peeled to4931982, published non-draft/non-prerelease, exactly3 uploaded assets | [Publication receipt](evidence/release-0.3.0/publication-1791863800600551728/publication-verification.json), [raw release API](evidence/release-0.3.0/publication-1791863800600551728/release-api.json) |
| Fresh published-asset downloads | PASS; all3 bytes/hashes equal qualified originals, sums2, source/version/1420 inventory/start_erl.data and remote tag/main verified | [Download receipt](evidence/release-0.3.0/publication-1791863800600551728/publication-verification.json); binary rerun NOT RUN because downloaded bytes are identical to the qualified artifact |
| Independent publication/download completion review | PASS; no findings, raw commands/API and exact fresh bytes independently checked | [Completion review](evidence/release-0.3.0/review-actual-publication-fresh-download-1791864019336220804.json) |
| Deployment, production, Vault/public management and release-artifact E2E | NOT RUN; restrictions unchanged | No deployment, operational certificates, production-data changes, public management or E2E workflow enablement |

The selected platform is Debian bookworm/glibc Linux x86_64 (`linux/amd64`),
Elixir1.18.5/OTP28.5.0.5 with immutable builder/runtime images recorded in the
receipts. Other platforms are unqualified. Parent runtime stages take61.407s
and child28.992s within unchanged600s/300s bounds and cleanup reserve. The owned
container is `gaoxy-release-030-portable-b9ebb66e9638459bbe872e9e5a953f30`;
runtime image is `sha256:2a4756c1c8ba7961248be2dcf38bdbfb2cb25e605c60f6a0f2770f6609489f78`.

| Published asset | Bytes | SHA256 |
| --- | ---: | --- |
| gaoxy-0.3.0-linux-x86_64.tar.gz | 9829475 | 257b91c9b97fa5c73b9718744249a3fc00511833aa81142e36924083a58cd902 |
| build-info.json | 20626 | 65189e901e88de2a5331784cf24f810d33244c8b030ec2c7ec5b73e24feca1cc |
| SHA256SUMS | 180 | faa434a007f737203ae8619a7f04692ea6d2a4dcb8e496607d9f7b0ac9980f44 |

The [raw final evidence manifest](evidence/release-0.3.0/portable-final-1791863003049561405/manifest.json)
retains its capture-time `PENDING_FINAL_REVIEW`; the later independent review
above closes that historical snapshot. All67 captured file hashes remain intact.
Build1 formatting FAIL, build2/runtime1 wrapper FAIL and the initial repair's
case-insensitive-name flaw remain visible below and in immutable receipts.
The corrected host scripts accept only a known absence prefix with nonzero
inspect and a case-sensitive exact owned name. Independent42 boundary scenarios
and26 pure vectors plus a fresh42-case repeat pass; deadlines, child exit0,
normal removal and forced-cleanup FAIL requirements remain unchanged.

The next prepared package is existing M3 Task4
[H1 resource foundation design](../designs/m3-h1-resource-foundation.md) and
[plan](../plans/m3-h1-resource-foundation.md). Its implementation is NOT RUN;
Task5 production pool activation remains separate. No M5 is added.

The clean next checkout was created from the frozen source at
`.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`;
[bootstrap receipt](evidence/release-0.3.0/next-task4-bootstrap-1791864162247441315.json)
records its exact tree and clean status. After independent documentation review,
root commits/pushes this documentation and fast-forwards the prepared branch to
that main. A separate parent handoff receipt records the final SHA/tree and
documentation-only difference, avoiding a self-referential commit identity.
Task4 Step0 implementation ownership and new-checkout runtime checks remain NOT RUN.

## Historical release preparation and failed qualifications

Date: 2026-10-13. Implementation executions and final independent M4
acceptance PASS. Publication pending. Initial builder failed formatting;
the corrected49cb7ab builder passed757/0, then runtime1 failed Docker29
absence-message recognition after successful packaged execution and normal removal.
The case-compatible host-runner repair requires a new committed build/runtime.

The [release execution plan](../plans/release-0.3.0.md),
[portable design](../designs/release-0.3.0-portable.md) and
[portable implementation plan](../plans/release-0.3.0-portable.md) define the
required gates. [Draft release notes](../releases/0.3.0.md) describe candidate
behavior. This skeleton records pending checks without assigning invented source
identities, executed counts, checksums or release URLs.

Preparation checkout: `.trees/m4-http3`, branch `codex/m4-http3`, HEAD
`d5831d7613e8c8edd2adf76fbd7b86b408e62de6`, with concurrent uncommitted M4 work.
This HEAD is a preparation baseline, not the final integrated release source.
Root has updated the umbrella and five application version declarations to0.3.0.
Final candidate verification/review/commit and source-identity capture remain
separate from the recorded preparation HEAD and M4 runtime receipts.

### Historical preparation ledger

| Gate | Current result | Evidence needed for acceptance |
| --- | --- | --- |
| Final M4 eligibility | Implementation executions and final independent acceptance PASS | [Final gate ledger](m4.md#final-implementation-gate-ledger--2026-10-13):530/0, strict builds, Session50, G0 reuse, G1/G2/G3 47/59/19, standalone16, clean consumers1/2/2, two complete reviewed UP2 68/68 executions |
| Current M4 history | Preserved immutable PASS/FAIL checkpoints | [M4 history](m4.md#historical-0214-dependency-and-repair-checkpoints); unsuccessful counters20/8/3 and prior snapshots remain |
| Six source versions | All six source versions0.3.0; five packaged versions PASS on49cb7ab | Build2 metadata/inventory in [preserved history](evidence/release-0.3.0/portable-build2-runtime1-failure-1791861327712037431/diagnosis.json); new candidate archive remains required |
| Local0.3.0 candidate format/strict builds/compatibility | PASS530/0;34 explicit formatting paths; strict umbrella/Phoenix/production compile exit0 | [Source](evidence/m4/upstream-matrix/candidate-030-source-1791856883681558593.json), [Phoenix](evidence/m4/upstream-matrix/candidate-030-phoenix-1791856954596394437.json), [production](evidence/m4/upstream-matrix/candidate-030-prod-compile-1791857005749451759.json); precommit d5831 baseline plus explicit source hashes, not final integrated archive identity |
| Local production artifact smoke | PASS: assembled0.3.0; core3, gateway2, H3 three checks | [Release assembly](evidence/m4/upstream-matrix/candidate-030-local-release-1791857193704442491.json), [core](evidence/m4/upstream-matrix/candidate-030-local-core-smoke-1791857318952921079.json), [gateway](evidence/m4/upstream-matrix/candidate-030-local-gateway-smoke-1791857371939263212.json), [H3](evidence/m4/upstream-matrix/candidate-030-local-h3-smoke-1791857681373587300.json) and [H3 peer result](evidence/release-0.3.0/local-h3-package-1791857824012345678/result.json): exact bytes/trailers, children exit0 and port rebind; host-scoped, separate from portable exported bytes |
| Independent final candidate review | PASS; no unresolved findings | [Final review](evidence/m4/upstream-matrix/review-m4-final-implementation-candidate-acceptance-1791858009332797257.json); source, notes, acceptance and actual local release evidence reviewed before candidate commit |
| Main integration/remote identity | e06b5e7 and49cb7ab PASS; host-runner repair candidate PENDING | [Original main integration/push](evidence/release-0.3.0/main-integration-1791858656314621577.json) and [corrected integration](evidence/release-0.3.0/corrected-main-integration-1791859607066545217.json); exact remote SHA and unrelated file preserved |
| Source archive/lock identity | e06b5e7 and49cb7ab PASS; host-runner repair candidate PENDING | [Original identity/build1 review](evidence/release-0.3.0/review-original-portable-source-identity-build1-failure-1791859121396391556.json) and [49cb identity review](evidence/release-0.3.0/review-corrected-portable-exact-source-identity-1791859806048366506.json):4106 exact committed regular files,82 paths,7 recipe copies and unchanged lock. New committed archive required |
| Portable builder | Build1 FAIL; build2 PASS757/0 on49cb7ab; new repair candidate PENDING | [Preserved build1 failure](evidence/release-0.3.0/portable-build1-failure-1791859105860499026/diagnosis.json) and [build2/runtime1 history](evidence/release-0.3.0/portable-build2-runtime1-failure-1791861327712037431/diagnosis.json). Build2 has five nonzero applications and zero exclusions/skips. New source-bound build remains required after the host-runner repair |
| Packaged H3 smoke | Build2 and runtime1 in-container PASSthree checks; repaired candidate PENDING | [Runtime1 scope review](evidence/release-0.3.0/review-original-portable-runtime1-failure-1791861403971008922.json): native H3 static, H1-to-H3 data+duplicate trailers, H3-to-H3 zero-data+duplicate trailers; child exits0 and port rebind. Overall runtime1 remains FAIL |
| Archive/version/inventory/checksums | Build2 PASS1420 safe entries/five versions/checksums; repaired candidate PENDING | [Scope review](evidence/release-0.3.0/review-original-portable-runtime1-failure-1791861403971008922.json) binds49cb source, archive digest and both SHA256SUMS entries; historical metadata in the preserved build2 directory |
| Fresh offline runtime | Runtime1 FAIL; repaired-source retry PENDING | [Immutable runtime1 review](evidence/release-0.3.0/review-original-portable-runtime1-failure-1791861403971008922.json): container core3/gateway2/H3three/ELF21 PASS, child exit0 and normal rm0; Docker29 lowercase `no such object` rejected by uppercase-only absence checks. Overall FAIL is retained; new source-bound runtime required |
| Packaged ELF linkage | Runtime1 in-container PASS21/all ELF; repaired candidate PENDING | [Scope review](evidence/release-0.3.0/review-original-portable-runtime1-failure-1791861403971008922.json): zero missing libraries/Nix dependencies; overall runtime1 remains FAIL |
| Independent actual artifact/runtime review | Historical49cb scope reviewed; full acceptance NOT ACCEPTED | [Failure/artifact-scope review](evidence/release-0.3.0/review-original-portable-runtime1-failure-1791861403971008922.json) preserves wrapper/parent/child FAIL. New source-bound artifact/runtime review required |
| Hosted CI/build | BLOCKED_ENV for e06b5e7 and49cb7ab; zero executed steps | [Initial audit](evidence/release-0.3.0/hosted-status-e06b5e7-1791858879765.json) and [49cb audit](evidence/release-0.3.0/hosted-status-49cb7ab-1791859848511.json): three runs/ten jobs each prevented from starting; new candidate remains separate, no workflow dispatch/settings change |
| Immutable tag/release assets | NOT RUN | Qualified bytes and completed review before immutable tag; verify remote tag/source and release assets |
| Fresh published-asset download | NOT RUN | Freshly downloaded archive/metadata/checksums match qualified bytes; source/version/inventory and remote main/tag verified |
| Deployment/production/release-artifact E2E | NOT RUN; excluded | No deployment, production data/certificates, Vault/public-management changes or enabling the disabled release-artifact E2E workflow |

### Recorded capability and profile boundary

The candidate includes native downstream H1/H2/H3 and fixed verified HTTPS/H3
reverse origins using a caller-owned public Session/dedicated endpoint. H1 remains
the default with dedicated per-request connections. Upstream H1 pools and upstream
H2 are not implemented; H3 has no automatic protocol fallback, pool or replay.
Fetch H3 functional diagnostics and unsupported Fetch cleanup completion remain
distinct from the selected Session lifecycle evidence.

[HTTP Fetch #105](https://github.com/gsmlg-dev/http_fetch/issues/105) is CLOSED
via PR#106/main`e17ceea`; published/installed0.21.4 lacks its fix, per the
[latest audit](evidence/m4/upstream-contract/latest-http-fetch-main-update-audit-1791855535947755021.json). Retain the original **needed** disposition, supported
`Session.new(max_frame: 8_192)` selection and
callsite TODO/WORKAROUND references. Preserve the16KiB application DATA ceiling,
exact1MiB bytes/hash/FIN and finite deadlines; installed dependency sources
remain unpatched and lack the containing upstream fix. See the [dependency record](../dependency-requests/http3-session-flow-credit.md).

The trusted embedded service option `quic.poll_interval` is bounded to
integer1..1000ms with omission10ms. UP2 explicitly selects1ms on both completed
H3 service specifications, revalidated through `Gaoxy.Config.service/1`, with
normalized fixture metadata assertions. The selected profile qualifies only its
explicit workload; default10ms tiny-window burst throughput remains unqualified.
H3 Options and the standalone data-only schema/defaults remain unchanged.

The planned artifact name is `gaoxy-0.3.0-linux-x86_64.tar.gz`, with
`build-info.json` and `SHA256SUMS`. Qualification targets Debian bookworm/glibc
Linux x86_64 only. Builder configuration selects Elixir1.18.5/OTP28.5.0.5 and the
pinned Debian/Rust images in the reviewed recipe; actual executed toolchain and
image identities must be recorded by the new build. No artifact source SHA,
digest, test total, ELF count or runtime duration is assigned before execution.

### Preserved preparation conditions and counters

Keep unique raw failure/success receipts under `evidence/release-0.3.0/`, including
source/environment, commands, actual counts/exits, log hashes, deadlines and
owned-process/container shutdown. Preserve all earlier M4 and v0.2.0 receipts
without modification. Current UP2 unsuccessful counters are20 live/8 production/
3 harness; prior repair11 checkpoint19/7/3, repair9 snapshot18/6/3 and repair8/pre-implementation17/5/3 remain; the agreed TDD RED adds no failed live repair. Historical counters and
the exhausted two Astra recovery rounds remain recorded; no third recovery.

The pending rows above describe the earlier preparation checkpoint.
The final evidence ledger at the top records their subsequent closure. Any source
change after archive capture requires refreshed identity and affected
qualification. Source acceptance, local release smoke, portable bytes, hosted CI,
publication/download verification and production acceptance remain separate.
