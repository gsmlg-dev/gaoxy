# M5 G3 independent review

SPEC NEEDS FIX, then CODE NEEDS FIX for one handoff defect: Connection.exchange/3:598-601 does not carry extended_connect into Exchange.limits. The PlugAdapter requires that exact locally normalizedtrue flag; consequently enabled native H3 Plug/Phoenix upgrades are always refused. Current H3 network test uses direct WebSocket.prepare, masking the adapter path. Carry the flag into H3 Exchange limits and qualify an ordinary Plug/H3 handoff with enabled/disabled behavior preserved.

No additional actionable findings in sevenproduction modules and operations/websocket/network testfiles. Reviewed owner-only publicQUIC I/O, immutable CONNECT metadata, localsetting8, lifetime replacement in owner+Operations before200 while keeping opening operation finite, independent bounded demand and consumed delivery accounting, same admitted worker, acknowledged output, no uncertain-write replay, and normalClose/FIN peerjoin and retirement. Existing cancel mapping remains0x10C; no specialist scenarios added.

Pure guard re-review SPEC PASS/CODE PASS: Headers/Protocol capability checks now ensure modules loaded first, preserving all test assertions. Initial guard finding remains in g3-pure-review.

Inspected g3-runtime-green82tests/0failures/exit0. Its log includes concurrentG4 compilerwarning; this is testPASS, not strictcompilePASS. IndependentH3peer and fresh parent checks remain pending. No builds or network commands run by reviewer. All review commands completed; no production/test edits. Source hashes in initial-snapshot.json. Review repair rounds0, inherited counters unchanged. G4Phoenix/vendor/browser acceptance separate.
