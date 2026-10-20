# Correctness patch integration and release

Date: 2026-10-20, Asia/Shanghai. The user's repair handoff authorizes local
implementation, independent review, integration, push and the next unused patch
release. Starting local main: `4f90967e06b906f3a862ec1541b1c4dd79bee83a`;
remote main: `c063607e65cb3486dc19c78827f1ea8c62dbc87a`. Published v0.5.2 remains
immutable. Worktree: `.trees/correctness-patch`, branch `codex/correctness-patch`.

1. Confirm runtime/locks, preserve user work, and reproduce R1/R2/R3 in separate
   tracks. R1 owns Exchange/accounting internals; other writers avoid them.
2. Implement bounded Plug aggregation, structured H2 authority rejection and
   shared request Cookie joining. Verify native compatibility and real protocol
   rows. Reuse the existing R4 neutral response repair and test before upstream
   side effects, including admitted extended CONNECT.
3. Update canonical guides against current source. The standalone expansion in
   `27bffd83` predates kickoff, so preserve its functionality and accurately
   describe it instead of implementing the handoff's stale future-work boundary.
4. Add an exact-count ordinary repair command and wire it into enabled unit,
   integration and release jobs. Do not run deferred specialist suites. Keep
   release-artifact E2E disabled and the sustained-load step deferred.
5. Extend clean HTTP/Phoenix consumers with actual 20,000-byte parsed bodies.
   Run scoped native/accounting/WebSocket compatibility, package regressions,
   canonical formatting, strict compilation, release build and ordinary core,
   gateway, H3 and source-bound browser/packaged-WebSocket gates.
6. Independently review specifications and code; fix findings without weakening
   assertions. Create logical conventional commits and synchronize version 0.5.3
   before final exact-source verification. Refresh the unused version check.
7. Fast-forward integrate, verify remote source, push and dispatch the existing
   release workflow with a full expected SHA. The workflow validates committed
   versions, runs the ordinary repair gate in test environment, and never
   generates an unverified source commit. Verify actual publication state before
   any retry; verify fresh GitHub/Hex bytes, tag/source and public consumers.

The [acceptance record](../acceptance/review-repairs-2026-10-20.md) distinguishes
PASS/FAIL/BLOCKED/NOT RUN. Preserve all historical specialist evidence, upstream
issue 97 dismissal, production/Vault/certificate/public-management boundaries,
and user-owned files. No dependency upgrades or operational deployment.
