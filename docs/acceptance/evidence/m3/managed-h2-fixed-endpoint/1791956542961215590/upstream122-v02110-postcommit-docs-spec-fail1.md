# Actual-commit documentation SPEC

FAIL_POSTCOMMIT_DOCUMENTATION_CURRENT_STATUS_CONTRADICTIONS. Two P2 findings.

1. implement-plan.md28-31: active Current checkpoint still says local commit/final review pending while the actual feature/evidence commits exist and later roadmap text says DONE locally. Update current status; preserve historical text.
2. docs/acceptance/m3-managed-h2-fixed-endpoint.md359,631,634: active ledger says final inventory/local commit NOT RUN and closure conditions stay unchecked despite actual authenticated commits and new DONE locally checkpoint. Rows346/358 should distinguish already passed closure reviews from the current postcommit-only review; do not claim the new review passed prematurely. Record actual commit/shutdown evidence and satisfied closure conditions while keeping live successor NOT_RUN ACCOUNTING_NOT_READY.

No actual identity findings: evidence5516ea1b398d7970e861cabdb2c2c3075be7eeae/tree1bad34baa9237cede9c2986beea9b9c864d34894 has8098 changed paths; featurebbbc50dc628d4d82fde7377b5bcff68bb35e1867/treef3f37602277e5b172076da0ecc5ca2b9ef233a68 has53 paths and the expected evidence parent. All57 accepted committed source/authority hashes and53 current runtime/authority hashes match. All8096 audit OIDs match actual committed evidence tree, audit totals1081175548bytes/zero mismatches; committed green/shutdown receipt bytes match disk.

Candidate1443cf51b6ca19316e33a1cf00e0554d6f5502940edbd8995af91e6d8bf94d4b and four document hashes remain stable. Historical failures, negative TLS cleanup uncertainty and counters remain unchanged. This is documentation-only; no runtime reexecution is required. Root should repair only current-status claims, freeze revised candidate and request fresh SPEC then CODE.

Repository/index writes: none. Only assigned /tmp reports written; all commands finished. No runtime/network/browser actors started or processes changed. Review consumed zero repair rounds; all prior counters and Astra2/2 preserved.
