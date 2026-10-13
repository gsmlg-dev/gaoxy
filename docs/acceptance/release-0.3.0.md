# Gaoxy v0.3.0 release acceptance preparation

Date: 2026-10-13. Implementation executions and final independent M4
acceptance PASS. Portable build/runtime and publication NOT RUN.

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
| Six source versions | Updated locally to0.3.0; packaged versions NOT RUN | Final candidate review and archive checks must bind all five packaged applications and release metadata |
| Local0.3.0 candidate format/strict builds/compatibility | PASS530/0;34 explicit formatting paths; strict umbrella/Phoenix/production compile exit0 | [Source](evidence/m4/upstream-matrix/candidate-030-source-1791856883681558593.json), [Phoenix](evidence/m4/upstream-matrix/candidate-030-phoenix-1791856954596394437.json), [production](evidence/m4/upstream-matrix/candidate-030-prod-compile-1791857005749451759.json); precommit d5831 baseline plus explicit source hashes, not final integrated archive identity |
| Local production artifact smoke | PASS: assembled0.3.0; core3, gateway2, H3 three checks | [Release assembly](evidence/m4/upstream-matrix/candidate-030-local-release-1791857193704442491.json), [core](evidence/m4/upstream-matrix/candidate-030-local-core-smoke-1791857318952921079.json), [gateway](evidence/m4/upstream-matrix/candidate-030-local-gateway-smoke-1791857371939263212.json), [H3](evidence/m4/upstream-matrix/candidate-030-local-h3-smoke-1791857681373587300.json) and [H3 peer result](evidence/release-0.3.0/local-h3-package-1791857824012345678/result.json): exact bytes/trailers, children exit0 and port rebind; host-scoped, separate from portable exported bytes |
| Independent final candidate review | PASS; no unresolved findings | [Final review](evidence/m4/upstream-matrix/review-m4-final-implementation-candidate-acceptance-1791858009332797257.json); source, notes, acceptance and actual local release evidence reviewed before candidate commit |
| Main integration/remote identity | NOT RUN | Reviewed integration, preserved unrelated work, exact local/remote main SHA and repeated affected verification if integration changes source |
| Source archive/lock identity | NOT RUN | `git archive --format=tar` from exact final integrated commit; source-identity.json with commit/archive SHA256/root lock SHA256; archived source bytes unchanged during build |
| Portable builder | NOT RUN | Reviewed fresh staged build at pinned toolchain; exact commands/env/log hashes; nonzero counts for all five application directories, zero failures/excluded/skipped |
| Packaged H3 smoke | NOT RUN | Three real checks: native H3 static, H1-to-H3 data+duplicate trailers, H3-to-H3 zero-data+duplicate trailers; exact origin bytes/hash/one FIN/identity, zero child exits and immediate rebind |
| Archive/version/inventory/checksums | NOT RUN | Safe inventory; five packaged0.3.0 application versions; release start version; archive digest and both archive/build-info SHA256SUMS entries |
| Fresh offline runtime | NOT RUN | New owned container from recorded immutable image; network none; readonly exported-artifact mount; packaged core/gateway/H3 smokes; finite wait/log capture/final inspection/owned cleanup |
| Packaged ELF linkage | NOT RUN | Inspect every extracted ELF with nonzero count, no missing libraries, no Nix paths and accepted linkage results |
| Independent actual artifact/runtime review | NOT RUN | Review exported bytes, identities, counts, checksums, inventory and all runtime/ELF evidence; repeat affected qualification after any change |
| Hosted CI/build | NOT RUN for this release | Record actual hosted outcome separately; a no-start job remains BLOCKED_ENV. The automatic publisher is not the selected publication route |
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
