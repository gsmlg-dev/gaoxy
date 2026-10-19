# Gaoxy v0.4.0 release acceptance

Date: 2026-10-19. **PREPARING; artifact and publication gates NOT RUN.** The user
explicitly authorizes commit/main integration/push/GitHub release following M5.
[Release plan](../plans/release-0.4.0.md) and
[portable design](../designs/release-0.4.0-portable.md) define ordinary-only gates.

| Gate | Current status |
| --- | --- |
| Implementation acceptance | PASS: accepted M3 ordinary 62/0; M5 136/0, peers15/15 each, browsers12/12 each; independent SPEC/CODE PASS |
| Remote baseline/version | PASS: latest published v0.3.0, v0.4.0 absent; origin/main449a4c4 ancestor of M5a2822c3 |
| Six source versions / new recipes | PASS: six declarations at 0.4.0; eight versioned recipe files; old recipes unchanged |
| Independent source/recipe review | PASS: SPEC then CODE, no actionable findings; static review only |
| Frozen committed source and main integration | NOT RUN |
| Portable builder / package metadata / checksums | NOT RUN |
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

Embedded managed H1/H2 and native WebSocket capability does not imply JSON schema
activation. Packaged WebSocket checks use public embedded release evaluation,
with no Mix/Phoenix development beams. H3 browser proof remains controlled
QUIC-first; automatic selection with TCP available remains unqualified. Prior
M3/M4/M5 and v0.2.0/v0.3.0 evidence and assertions remain immutable. Cumulative
repair categories remain separate; Astra recovery remains exhausted at 2/2.
