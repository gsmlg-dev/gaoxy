# Gaoxy v0.4.0 release acceptance

Date: 2026-10-19. **FRESH PORTABLE QUALIFICATION PASS; three historical attempts retain FAIL;
publication/download/completion gates PENDING.** The user
explicitly authorizes commit/main integration/push/GitHub release following M5.
[Release plan](../plans/release-0.4.0.md) and
[portable design](../designs/release-0.4.0-portable.md) define ordinary-only gates.

| Gate | Current status |
| --- | --- |
| Implementation acceptance | PASS: accepted M3 ordinary 62/0; M5 136/0, peers15/15 each, browsers12/12 each; independent SPEC/CODE PASS |
| Remote baseline/version | PASS: latest published v0.3.0, v0.4.0 absent; origin/main449a4c4 ancestor of M5a2822c3 |
| Six source versions / new recipes | PASS: six declarations at 0.4.0; eight versioned recipe files; old recipes unchanged |
| Independent source/recipe review | PASS: SPEC then CODE, no actionable findings; static review only |
| Formatter repair review | PASS: fresh SPEC then CODE; full identity and all-file custody retained |
| Peer-environment repair review | PASS: fresh SPEC then CODE; matching environment with pins/assertions unchanged |
| Ordinary H2 group compatibility repair | SPEC/CODE/result review PASS; cached test-only RED reproduced both regressions, then repaired ordinary 200/0 with 90 deselections |
| Frozen committed source and main integration | PASS: frozen source `ebd2b12a997750109ffd3fc7db4f3eda223ab79b` qualified; host source/archive and final clean-source custody recorded |
| Portable builder / package metadata / checksums | PASS: fresh 200/0, 90 excluded, 0 skipped; 21,812 unchanged source files; 1,439 entries; five packaged applications 0.4.0; both checksums verified. Historical three attempts retain FAIL |
| Packaged WS / existing smokes / offline runtime / ELF | PASS: H2/h2c/H3 15/15 each in builder and offline runtime; core3/gateway2/H3 3 smokes per environment; network none; 21 ELF/0 missing/0 Nix; normal exit/removal/absence |
| Independent actual artifact/runtime/notes review | `PENDING_ARTIFACT_RUNTIME_NOTES_REVIEW` |
| Push / annotated tag / GitHub release | `PENDING_PUBLICATION_RECEIPT` |
| Fresh asset downloads / independent completion review | `PENDING_DOWNLOAD_VERIFICATION`; `PENDING_FINAL_COMPLETION_REVIEW` |
| New hosted CI | NOT RUN; push markers retain ordinary-only scope; old BLOCKED_ENV unchanged |
| Deployment / production / specialist qualification / release-artifact E2E | NOT RUN; excluded |

The source baseline is M5 `a2822c35dd4dd7ea99a84fb528b9db129990e6f1` on the
retained isolated branch. Root lock remains SHA256
`c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6`.
Fresh source/archive/artifact identities, toolchain and executed/excluded counts
are recorded below. Independent final review and remote/download proofs remain
pending until their actual receipts exist.

## Fresh frozen-source portable qualification — PASS

Frozen source `ebd2b12a997750109ffd3fc7db4f3eda223ab79b` completed the fresh ordinary portable run
`portable-1792408662674538754` at `2026-10-19T11:32:09.700707+00:00`.
The host receipt records the committed-source/archive identity and clean source
at completion. Archive/Git custody verified **21,812 regular files**, and the
builder's final unchanged-source check verified the same count. Canonical format,
all **171 current changed Elixir paths**, and strict production compilation passed.
The remaining **4,993 historical changed Elixir paths** retain byte custody; the
formatter partition does not exclude them from source identity or custody.

Fresh ordinary verification executed **200 invocations / 0 failures / 90 excluded /
0 skipped**: M5 **138** (55 HTTP + 83 H3), M3 unit **38** (30 proxy + 8 server),
and M3 network **24**. These are executed invocations across the recorded commands,
not a claim of 200 unique tests. All original selectors/assertions remain in force.
The historical M5 136/0 acceptance and cached RED/GREEN counts below retain their
capture-time identities; this fresh source run is a separate later result.

The Linux amd64 artifact contains **1,439 safe archive entries** and all five own
packaged applications at **0.4.0**. Both SHA256SUMS entries verify. The qualification
supports **Debian bookworm/glibc x86_64** only; other platforms remain unqualified.
The recorded toolchain is Elixir 1.18.5, OTP 28.5.0.5 / ERTS 16.4.0.5, Rust 1.97.1,
Python 3.11.2, OpenSSL 3.0.22 and glibc 2.36. Full package/toolchain and command
records remain in build-info and raw receipts.

| Qualified bytes | SHA256 |
| --- | --- |
| Source tar archive | `c98f3a6a8b80af973d55995929ef5baaaf26fb34eb035ad66aadaeece5360e2c` |
| Root lock | `c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6` |
| `gaoxy-0.4.0-linux-x86_64.tar.gz` | `b55c53e6751d854b4892434e44b407dd341f98c54d1b042c87623a9c1b595408` |
| `build-info.json` | `6704c2884e77503691a6e904b49507bd666eb197bad318ab0ecc1917616cf418` |
| `SHA256SUMS` | `f389141c704b5a6b3643c6af8b8382df6f43336e4387016ee12eaf77237244b2` |

Existing packaged smokes passed in both builder and fresh offline runtime:
**3 core transports, 2 gateway exchanges and 3 H3 checks** per environment.
Packaged WebSocket H2, h2c and H3 each passed **15/15** in the builder and **15/15**
again in the fresh offline runtime, using public embedded release evaluation
without Mix/Phoenix development beams. All six profiles record normal exit 0,
runtime down, zero active/retained/cleanup-pending admission and removal of their
ephemeral private keys. These peer profiles are separate from historical browser
evidence and do not establish automatic browser H3 selection.

The fresh runtime used **`--network none`**, inspected **21 ELF objects**, and
reported **0 missing libraries / 0 Nix ELF dependencies**. Its owned container
exited **0**, was removed normally and was observed absent. Runtime qualification
reported PASS within its finite deadline; no forced cleanup is counted as success.
The evidence resides in local `.audit/release-0.4.0/portable-1792408662674538754/`:
`evidence/host-qualification.json`, `artifacts/build-info.json`,
`evidence/runtime-qualification-stages.json`, and
`evidence/fresh-runtime/{runtime-result,launch}.json`, with raw command streams
and separate per-profile reports.

## Outstanding release gates

- Actual artifact/runtime/final-notes independent review: **`PENDING_ARTIFACT_RUNTIME_NOTES_REVIEW`**.
- Push/main identity, annotated tag/peeled identity, GitHub release and exact three assets: **`PENDING_PUBLICATION_RECEIPT`**.
- Fresh download bytes/checksums, package inventory/source/versions and release/ref checks: **`PENDING_DOWNLOAD_VERIFICATION`**.
- Independent completion review, final documentation/evidence commit/push and remote-main custody: **`PENDING_FINAL_COMPLETION_REVIEW`**.

No pending gate is inferred from local qualification. Hosted CI remains separate;
the earlier BLOCKED_ENV evidence retains its status. Deployment, production and
specialist qualification remain excluded. Parent fills these pending values only
from actual corresponding receipts.

## Historical failed attempts and bounded repair — retained verbatim

Initial candidate `4dd24f2ca28c6376c95daeb10dc3464b7d5dbcb2` passed archive/Git
custody for 21,743 regular files, toolchain/dependency preparation and canonical
formatting. Its changed-file formatter failed on 91 immutable historical paths
under `docs/acceptance/evidence/`, with zero current source paths failing.
Strict compilation, ordinary tests, packaging and runtime were NOT RUN in that
attempt. The bounded repair retains all 5,160 changed Elixir paths in identity,
formats all 171 current paths, and preserves the 4,989 historical paths through
the original all-file unchanged-byte check. The failed raw log is retained
losslessly; no historical source or assertion is reformatted or weakened.

Second candidate `4fbd15fe58cfbb67450a060fddf9e1e87bd813e1` passed archive/Git
custody for 21,753 regular files, canonical and all 171 current changed-file
format checks, strict production compilation, M5 136/0 and M3 unit 38/0.
The ordinary network command reported 114 defined, 90 excluded, 24 executed and
16 failures. All 16 stopped at the unchanged Python dependency-version guard
before protocol exchange: the fixed M3 fixture executable selected legacy
`h2peer` (hpack 4.2.0) instead of the required hpack 4.1.0. The bounded repair
selects existing `m5peer` after its installation, retaining both environments,
all pins, commands and assertions. Packaging, packaged smokes/WebSocket, final
builder source custody and offline runtime were NOT RUN in that attempt.
The failed build remains FAIL with peer-environment classification; its raw log,
host receipt and diagnosis are archived losslessly under
`evidence/release-0.4.0/failed-peer-env-1792405393768168873/`.

Third candidate `9253b787b57b768682bb4d894f25ca82919c0a94` passed archive/Git
custody for 21,762 regular files, both format checks, strict production compile,
M5 136/0 and M3 unit 38/0. The network command executed 24 cases with 2 failures
and 90 exclusions; all independent-peer version guards passed. Only ordinary
H2 downstream requests through the H2/h2c managed group returned 503 instead of
200. Static tracing identifies newly attached WebSocket-only configuration in
ordinary Exchange limits, rejected by the unchanged strict group-accounting
grammar. A same-builder diagnostic reproduced only the four existing positive
group cases: 28 defined, 24 excluded, 4 executed and the same 2 failures. The
unaltered validator accepted H1's 14 integer limits and rejected H2's 16-field
map containing the two WebSocket fields; tracing reported zero unmatched calls
and the temporary test helper was restored byte-for-byte. Independent diagnostic
review confirms the cause, while product tests retain FAIL. The bounded H2/H3
Exchange repair keeps ordinary limits and strict accounting unchanged, retaining
WebSocket metadata only on actual WebSocket requests. Two regressions in already
selected files increase the next M5 scope to 138 (55 HTTP + 83 H3), and the full
next ordinary scope to 200 with the original 90 network deselections.
Packaging, packaged smokes/WebSocket, final builder custody and offline runtime
were NOT RUN. Raw failure, host receipt and initial diagnosis remain losslessly
preserved under `evidence/release-0.4.0/failed-group-1792406728693375161/`.

The bounded repair snapshot passed independent SPEC then CODE review before
execution. In the cached pinned builder, only the two new tests were first
overlaid on the original production files: each executed once and failed at
its ordinary-limit equality assertion (exit 2), confirming both regressions.
After overlaying the two reviewed production files, formatting, strict
production compilation and the unchanged ordinary selectors passed: M5 138/0,
M3 units 38/0 and M3 network 24/0 with 90 deselections, 200 executed in total.
Independent executed-result review passed. Raw streams, frozen input snapshot,
commands, hashes and all three reviews are archived losslessly under
`evidence/release-0.4.0/group-compat-repair3/`.
This snapshot check is separate from the next frozen-source portable build;
it grants no artifact, offline-runtime or publication acceptance.

Embedded managed H1/H2 and native WebSocket capability does not imply JSON schema
activation. Packaged WebSocket checks use public embedded release evaluation,
with no Mix/Phoenix development beams. H3 browser proof remains controlled
QUIC-first; automatic selection with TCP available remains unqualified. Prior
M3/M4/M5 and v0.2.0/v0.3.0 evidence and assertions remain immutable. Cumulative
repair categories remain separate; Astra recovery remains exhausted at 2/2.
