# Issue 11 implementation plan

1. Add a real TCP/public Plug reproduction for a complete 65,536-byte pipeline;
   record its failing baseline outside Git in `.audit/issue11`.
2. Make the smallest exchange change: allow observation at the inclusive limit,
   and reject an actual excess byte before concatenation. Keep admission and
   deadline enforcement and transport dispatch intact.
3. Update intentional old boundary tests to require actual excess, verifying
   unchanged retained pipeline and admitted probe floor. Add boundary idle,
   closure and admission checks and coalesced/after-body public TCP cases.
4. Document the public return-state/error contract and integration pattern.
5. Run nonempty scoped ExUnit verification through `scripts/check-tests.py`,
   nearby HTTP/1 lifecycle and HTTP/2 isolation tests, then scoped formatting.
   Parent coordinates independent review, fresh ordinary checks and release.
