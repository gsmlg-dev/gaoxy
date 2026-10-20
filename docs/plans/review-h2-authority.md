# H2 authority repair execution plan

Date: 2026-10-20 (Asia/Shanghai)

Base: `4f90967e06b906f3a862ec1541b1c4dd79bee83a` in the shared
`.trees/correctness-patch` worktree.

1. Reproduce missing authority with a focused pure header regression and a
   dedicated independent Python h2 peer; retain exact red evidence.
2. Add the binary authority requirement at the H2 origin boundary. Verify valid
   authority-only, Host fallback, equivalence/default ports, invalid authority,
   and CONNECT/extended CONNECT contracts. Make shared IPv6 parsing total for
   invalid UTF-8 bytes using strict byte parsing, backed by a red regression.
3. Verify the malformed stream reset, active sibling completion, PING and third
   request over one connection. Run existing scoped parser/H2 header and H3
   compatibility cases and formatting, serialized through the shared Mix lock.
4. Hand off the owned diff and bounded evidence for independent review. The
   integrator owns canonical acceptance/CI/release integration and commits.

Evidence directory: `.audit/review-repairs/track-b/`. Qualification uses Linux,
Elixir 1.18.5 / OTP 28.5 with `ELIXIR_ERL_OPTIONS='+S 4:4'`, the existing pinned
Python h2 environment and the locked dependency cohort. Red outcomes are
retained independently from green outcomes.
