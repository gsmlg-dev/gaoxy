# Gaoxy v0.4.0 release acceptance

Date: 2026-10-19. **PREPARING; two build attempts failed; publication NOT RUN.** The user
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
| Frozen committed source and main integration | PASS for candidates 4dd24f2 and 4fbd15f; next repair pending |
| Portable builder / package metadata / checksums | FAIL: initial formatter scope; second attempt peer-environment guard; repaired build NOT RUN |
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

Embedded managed H1/H2 and native WebSocket capability does not imply JSON schema
activation. Packaged WebSocket checks use public embedded release evaluation,
with no Mix/Phoenix development beams. H3 browser proof remains controlled
QUIC-first; automatic selection with TCP available remains unqualified. Prior
M3/M4/M5 and v0.2.0/v0.3.0 evidence and assertions remain immutable. Cumulative
repair categories remain separate; Astra recovery remains exhausted at 2/2.
