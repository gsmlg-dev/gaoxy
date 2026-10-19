# Ordinary Exchange repair CODE — PASS, pre-execution only

Reviewed the four actual source files, synchronized scope/verifier and frozen cached snapshot against baseline `9253b787b57b768682bb4d894f25ca82919c0a94`. No actionable findings. Input hashes are recorded in the JSON receipt.

Ordinary H2/H3 Exchange construction preserves native HTTP limits; actual WebSocket requests retain existing metadata. Connection settings and strict accounting remain unchanged. Two new ordinary regressions cover false/true opt-in and actual WebSocket metadata. Existing WebSocket/group assertions and fixtures are intact. All four snapshot files equal working bytes; only H2 test formatter wrapping differs from the SPEC proposal.

Scope changes only 54→55 HTTP and 82→83 H3. Selectors and 90 exclusions remain intact. Reversing only those counts and the scope hash reconstructs the exact previously reviewed download verifier. Its source pin remains the preparatory baseline and requires final committed-source binding later.

The harness checks baseline identity/hashes before copying tests, executes two named test-only RED regressions with exact expected failures, rechecks baseline production hashes, then applies production snapshots. It requires formatting, strict compilation and 200 ordinary executions with 90 exclusions. It preserves raw streams, exits, hashes and timeout evidence. RED and GREEN are both NOT RUN at review time. This PASS permits parent execution and accepts no product, artifact or release outcome.

Validation: static review, Python AST/hash checks, archive byte comparisons and exact reverse/prefix checks. No Git, builds, tests, runtime, browser or network commands. Only ignored review receipts were written. All reviewer commands finished; parent processes were untouched. Reviewer repairs: 0; completed release Sol repairs: 2; proposed repair: 3; inherited Astra: 2/2, unchanged.
