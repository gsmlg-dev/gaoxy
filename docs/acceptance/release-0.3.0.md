# Gaoxy v0.3.0 release acceptance preparation

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

## Required evidence ledger

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

## Capability and profile boundary

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

## Preservation and closure

Keep unique raw failure/success receipts under `evidence/release-0.3.0/`, including
source/environment, commands, actual counts/exits, log hashes, deadlines and
owned-process/container shutdown. Preserve all earlier M4 and v0.2.0 receipts
without modification. Current UP2 unsuccessful counters are20 live/8 production/
3 harness; prior repair11 checkpoint19/7/3, repair9 snapshot18/6/3 and repair8/pre-implementation17/5/3 remain; the agreed TDD RED adds no failed live repair. Historical counters and
the exhausted two Astra recovery rounds remain recorded; no third recovery.

Only root's actual final PASS receipts can close these pending rows. Any source
change after archive capture requires refreshed identity and affected
qualification. Source acceptance, local release smoke, portable bytes, hosted CI,
publication/download verification and production acceptance remain separate.
