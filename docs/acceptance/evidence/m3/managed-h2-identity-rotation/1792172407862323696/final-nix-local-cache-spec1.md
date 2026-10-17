# Frozen local-cache plan1 independent SPEC review

**FAIL — SPEC1-01 must be repaired before execution.** The plan promises a global1680s preparation limit, but helper1 uses it only to select curl max-time. `communicate(timeout=limit+10)`, full-file hashing, publication, aggregate PASS and receipt creation do not enforce that deadline. It may therefore report PASS after1680s while still finishing inside the separate1800s collector guard. No execution or actual overrun is claimed.

Preserve plan1/helper1 and this FAIL. Freeze a replacement that enforces the stated deadline across transfer, hashing, publication and aggregate success, retains failures/partial evidence and custody, and preserves all existing outer/materialization/protocol guards. Require fresh SPEC then dependent CODE PASS.

Static checks passed: all frozen input/helper/archive/collector/flake hashes; all411 implementation pins; exact18 original narinfo bytes, fields, recorded hash conversions and unique filenames;986177930 compressed bytes and3174429520 signed NarSize bytes;147 external refs,18 inset non-self edges,15 self references; dependency-first ordering and exact native copy/verify targets. Recorded165 individual validity observations cover18 invalid targets plus147 valid external refs. These are historical observations; the plan correctly requires fresh native preflight.

The native API/signature/content requirements, terminal custody gate, unchanged600s exact-version readiness, separate derivation-materialization boundary and no-acceptance restrictions remain specified. This review attests neither daemon settings, complete-file transfer, signature validity, Nix registration nor shell readiness.

Read-only SPEC scope:0 tests,0 downloads,0 Nix/store operations,0 fixture/browser runs,0 Git commands and0 repository/evidence writes. Only the two authorized /tmp reports were written. All reviewer commands completed; parent-owned session5204 was neither queried nor touched. One reviewer JSON-display error was corrected by bounded static reads; it did not execute the candidate or increment repair counters.

Inherited baseline8f6b884524d81d8defa7c5081230b8ab635e8107, not rechecked through Git. Sol5/production repairs0/Astra2of2 exhausted remain unchanged. Final browser FAIL/UNKNOWN and group NOT RUN remain. Dependent CODE and all execution remain NOT RUN. Exact reviewed input hashes and findings are in the accompanying JSON.
