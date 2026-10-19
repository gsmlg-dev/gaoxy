# Gaoxy v0.4.0 release acceptance

Date: 2026-10-19. **PREPARING; three build attempts failed; publication NOT RUN.** The user
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
| Frozen committed source and main integration | PASS through candidate 9253b78; reviewed compatibility repair awaits commit and fresh artifact qualification |
| Portable builder / package metadata / checksums | FAIL: formatter scope, peer-environment guard, then two ordinary H2 group cases; next repaired build NOT RUN |
| Packaged WS / existing smokes / offline runtime / ELF | NOT RUN |
| Independent actual artifact/runtime/notes review | NOT RUN |
| Push / annotated tag / GitHub release | NOT RUN |
| Fresh asset downloads / independent completion review | NOT RUN |
| New hosted CI | NOT RUN; push markers retain ordinary-only scope; old BLOCKED_ENV unchanged |
| Deployment / production / specialist qualification / release-artifact E2E | NOT RUN; excluded |

The source baseline is M5 `a2822c35dd4dd7ea99a84fb528b9db129990e6f1` on the
retained isolated branch. Root lock remains SHA256
`c93b608b77c457e4324430544c1acc2b384ee21e1a2b8ab528bad248ac666cb6`.
Actual source/archive/artifact hashes, toolchain versions, executed/excluded
counts, commands/exits, review and remote/download proofs are added after they
exist. No candidate document assigns invented successful execution.

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
