# Gaoxy v0.5.0 release acceptance

Date: 2026-10-20, Asia/Shanghai. **PUBLISHED; fresh portable qualification and
independent artifact/runtime/notes and publication/download reviews PASS.** The user explicitly authorized
commit, push and the next minor GitHub release.
[Release plan](../plans/release-0.5.0.md) and
[portable design](../designs/release-0.5.0-portable.md) define ordinary-only gates.

| Gate | Actual status |
| --- | --- |
| Preparation baseline | PASS: latest v0.4.0 and absent v0.5.0; two local Hell commits, no remote-only commits; tracked-clean checkout and unrelated prompt absent at this request |
| Accepted Hell implementation | PASS: the 429-file functional migration snapshot was verified before changing six release versions; runtime product code unchanged |
| Six source versions and recipes | PASS: root plus five own apps at 0.5.0; example version, all locks, dependency cohort and toolchain pins unchanged; eight versioned recipes |
| Independent specification and code review | PASS: SPEC then CODE; one static publisher approval-binding finding repaired and independently re-reviewed; original FAIL preserved |
| Frozen source and local main integration | PASS: `b0e1531b9d2ac682e4af19d4616ad4461e3ca6f2`, conventional `[skip ci]` preparation commit, clean source frozen until publication |
| Formatting, strict production compile and ordinary suites | PASS: 210 executions / 0 failures / 144 excluded / 0 skipped across four recorded invocations |
| Portable package, custody and Hell metadata/startup | PASS: 22,125 unchanged source files; 1,439 safe archive entries; five packaged own apps 0.5.0; Hell 0.1.2 present/started, Gaoxy depends on `:hell`, old application absent |
| Packaged WebSocket, existing smokes and offline runtime | PASS: H2/h2c/H3 15/15 each in both environments; core3/gateway2/H3checks3 each; network none, readonly artifact input, normal exit/removal/observed absence |
| ELF dependency inspection | PASS: 21 ELF objects, 0 missing libraries, 0 Nix dependencies |
| Independent actual artifact/runtime/notes review | PASS: exact source/run/qualification, three asset digests and final notes bound; no findings |
| Push, annotated tag and GitHub release | PASS: main pushed at qualified source; annotated v0.5.0 tag and latest stable release with exactly three assets |
| Fresh asset downloads | PASS: three assets byte-identical to qualified originals; hashes, two-entry checksum file, source/Hell metadata and safe inventory verified |
| Independent publication/download review | PASS: downloaded bytes, package metadata and live remote release/refs independently verified; no findings |
| Documentation closeout | Published results and lossless evidence recorded here; separate final review receipt accompanies this documentation commit |
| New hosted CI | NOT RUN: no runs observed for the release source; commits retain `[skip ci]` |
| Specialist qualification, deployment, production and release-artifact E2E | NOT RUN here; excluded |

## Frozen source and fresh execution

Qualified source: `b0e1531b9d2ac682e4af19d4616ad4461e3ca6f2`.
Run: `portable-1792426826677974240`.
Source archive SHA256:
`6d377d6f9cb0729ac25f7ddd95f9d3f5db7713c370f08170d078c3261c2147fb`.
Source identity SHA256:
`8f2a44bc4237951a9c2534453197856ef02199f8d3ca2bcb063f2602859033bd`.

Hell is version 0.1.2 at Git pin
`59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`; root lock SHA256 remains
`9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`.
All lockfiles retain their accepted migration bytes. The standalone archive is
qualified for **Linux amd64/x86_64, Debian bookworm/glibc**. Actual toolchain:
Elixir 1.18.5, OTP 28.5.0.5 / ERTS 16.4.0.5, Rust 1.97.1 and Python 3.11.2.
Broader operating systems, architectures and libc variants remain unqualified.

The fresh builder passed canonical formatting, all 43 current changed Elixir
paths and strict production compilation. The one historical recipe Elixir path
remains under full byte custody. All 22,125 regular source archive files were
also independently matched to their Git blob identities.

| Ordinary invocation | Executed | Failures | Excluded | Skipped |
| --- | ---: | ---: | ---: | ---: |
| M5 compatibility | 138 | 0 | 0 | 0 |
| M3 units | 38 | 0 | 0 | 0 |
| M3 network | 24 | 0 | 90 | 0 |
| Hell native ordinary | 10 | 0 | 54 | 0 |
| Total across invocations | 210 | 0 | 144 | 0 |

These are executed invocations, not a unique-test claim. Selectors and assertions
remain unchanged. Packaged independent-peer checks add 45 cases per environment
(H2, h2c and H3, 15 each). Existing core TCP/TLS/UDP, gateway H1/H2 and three H3
smoke checks passed in builder and fresh offline runtime. The public packaged
release started Hell 0.1.2 and confirmed its dependency/application metadata in
both environments. Runtime completed normally within the retained bounds, with
its owned container removed and observed absent.

[Host qualification](evidence/release-0.5.0/portable-1792426826677974240/host/host-qualification.json)
binds the build/finalize/runtime command receipts, actual logs, identities and
asset digests. Exact absolute arguments, effective environment, times, counts,
exits and log hashes are retained in those receipts and
[build metadata](evidence/release-0.5.0/portable-1792426826677974240/metadata/build-info.json).
The [runtime result](evidence/release-0.5.0/portable-1792426826677974240/host/fresh-runtime/runtime-result.json)
and [runtime stages](evidence/release-0.5.0/portable-1792426826677974240/host/runtime-qualification-stages.json)
record network isolation, all 21 ELF checks and normal cleanup.

## Publication and integrity

[GitHub v0.5.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.5.0), release
ID `417514896`, is public, stable, latest and non-draft. Annotated tag object:
`35347cf4038b34e16a0db148b9caa336c4450e8d`; its peeled source and remote main at
publication equal the qualified source above. Documentation closeout advances
main separately while preserving the qualified tag and all product/lock/recipe
bytes.

| Asset | Bytes | SHA256 |
| --- | ---: | --- |
| gaoxy-0.5.0-linux-x86_64.tar.gz | 10079133 | `3e750adae17bb8ecf8ecb3da3889bc743a43006432179a23c33bf76190a7d128` |
| build-info.json | 33377 | `23d274338313577dbb7b9a66ea543e0767f0866f9dca098a1eadb7d9e0443613` |
| SHA256SUMS | 180 | `ecf4e48f6b6945797ab2473a5f6af51200ecf40dc24fad58e84e331863699598` |

[Publication receipt](evidence/release-0.5.0/portable-1792426826677974240/publication/publication.json)
records successful push/tag/release commands and remote ref/metadata checks.
[Fresh-download verification](evidence/release-0.5.0/portable-1792426826677974240/publication/download-verification.json)
records exact three-file byte equality, checksums, source/version/Hell metadata
and the safe 1,439-entry inventory.

The 128-file [lossless archive manifest](evidence/release-0.5.0/portable-1792426826677974240/manifest.json)
binds archived receipts, logs, execution scripts and independent reviews. All
128 files passed byte-for-byte round-trip checks, including lossless gzip logs.
[Artifact/runtime/notes review](evidence/release-0.5.0/portable-1792426826677974240/operations/review-artifact-runtime-notes.json)
and [publication/download review](evidence/release-0.5.0/portable-1792426826677974240/operations/review-publication-downloads.json)
record their exact inspected evidence and successful independent checks.
Large raw source archives and qualified/downloaded assets remain in their local
run directories; the three release assets are on GitHub. No private keys or
dependency checkouts are included. Historical v0.4.0 and migration evidence is
unchanged. The repaired static CODE finding retains its original FAIL receipt;
product Sol repairs remain 0 and inherited Astra usage remains exhausted at 2/2.

[Documentation closeout evidence](evidence/release-0.5.0/closeout/) retains
validation and the final independent review separately from the 128-file
release archive. The parent verifies this documentation commit's remote main,
unchanged qualified tag, clean tracked state and functional-byte custody after
commit/push.

## Retained product and verification boundaries

[Release notes](../releases/0.5.0.md) record embedded/JSON activation differences,
protocol defaults and remaining H3/WebSocket limitations. Existing
[migration acceptance](hell-migration.md), including browser evidence, retains
its exact original source identities. Fresh release peer checks do not claim a
new browser run or automatic browser H3 selection with TCP available.

Specialist abnormal/disconnect, slow-peer, pressure, load and soak qualification
remain excluded and assigned to their dedicated environment. Historical failed,
blocked and unexecuted results and all assertions remain preserved. Deployment,
production operations, Hex/OCI publication, production data/certificates, Vault,
public management and the disabled release-artifact E2E remain outside this
release.
