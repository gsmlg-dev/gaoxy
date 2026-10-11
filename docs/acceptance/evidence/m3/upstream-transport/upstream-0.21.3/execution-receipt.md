# M3 0.21.3 local qualification receipt

The selected public functional contracts pass. Full M3 acceptance remains **BLOCKED** on [http_fetch#97](https://github.com/gsmlg-dev/http_fetch/issues/97), refreshed OPEN at delivery. Managed activation, full H2 accounting/backlog, P0–P6, managed integration/soaks and M4 remain gated. The task dependency audit identified no additional independent product implementation that can proceed before this contract.

The seven installed packages are 0.21.3, tag `ceecbf2df62ca80c361597c7303f65a153f2ce3c`, tree `6a44b862e8a09fb2648e48f928e37c20b1c8109a`. Seven archives, 196 shipped files and 175 runtime sources are verified. This continues the implementation on `codex/m3-gateway` from base `85c2284a035e0b4ecbf577279eee01142702b5a3`; local Git history identifies delivery commits.

| Gate | Actual evidence | Verdict |
| --- | --- | --- |
| Compatibility | 486 tests, zero failures, exit0 | PASS |
| Public managed properties | 39/39, 39 cleanups, capacity MATCH, exit0 | PASS functional only |
| H1 final source | Baseline20/0 and B21 1/0, no exclusions/skips, all owned joins, exit0 | PASS functional only |
| TLS supplemental | Positive5/5, cleanup5, exit0; old0.21.1 negative2 exact mismatches, cleanup2, exit1 | PASS stated oracles |
| H2 normal | 8/8, TLS4/h2c4, zero failed/skipped, eight peers joined, exit0 | PASS functional only |
| H2 failure-path regressions | Five expected negatives, four retained FAIL and one BLOCKED_HANDOFF; every VM really exits1 | PASS expected negative oracles |
| Native identity | Exact before/after profile equality, 254 regular hashes, 113 ELF paths, 483 unique NAR rows | PASS identity only |
| Final affected checks | Canonical format, strict compile, scoped proxy44/0, stable inputs and no surviving peers | PASS |
| Independent review | H1/H2 specification, code and evidence; no findings | PASS within stated scope |
| Complete managed resource accounting / activation | N8/native frontier UNESTABLISHED; #97 OPEN | BLOCKED |

The failure-path controls preserve the original errors. Prerepair variants omit cancellation/recovery and observe reset0. Repaired manual/follow variants publicly cancel, recover only the first response and observe reset8; stream DOWN `:noproc`/`:normal` remain exact. The lost Task reply alias preserves its real 2000ms timeout, performs public abort, never repeats await, and reports unresolved response ownership. Negative `System.halt(1)` bypasses wrapper post-identity/outcome: these and loaded-after identity are **NOT RUN**, with parent input freezes and actual VM/process-group/peer joins verified separately. None is added to the normal eight-case PASS count.

B21 records two ClientHellos, third-admission rejection at C2, pending then genuine cleanup_unconfirmed results, 15 actor joins, eight controls still charged, three occupied attempts and zero refunds. It does not establish native reclamation. Both H1 saved trees contain 69 raw files: baseline owns63 current runtime files plus six historical/auxiliary; B21 owns six current runtime files plus63 historical/auxiliary. The original failed analyzer and its corrected selection remain visible.

All original red, timeout and blocked receipts are retained. Cumulative counters remain H1 Sol3/unsuccessful2/Astra1; TLS tooling Sol4/unsuccessful2/Astra2; model Sol2/unsuccessful1/Astra0; H2 Sol1/unsuccessful0/Astra0. No third Astra round is authorized. The frozen H1 admitted inventory/gate, earlier complete0.21.2 accounting design/plan and hard-hashed H2 normal plan are historical pre-execution snapshots; do not rewrite their pending states as runtime observations. This receipt and current execution evidence supply their final disposition.

The existing53-file tooling preservation remains untouched. Supplemental38-file preservation contains the new analyzers, binding/builder/runner, five source/peer variants, originals, diffs and six input manifests. Saved-path mappings retain exact bytes without archiving disposable TLS private keys.

See [machine-readable status](qualification-status.json), [independent review](m3-h1-h2-final-independent-review.md), [failure-path analysis](h2-acquisition-failure-regression-analysis.json), [native comparison](h2-native-profile-final-comparison.json) and [supplemental tooling preservation](delivery-tooling-source-preservation.json). Commands, original deadlines, environments, exits and source hashes remain in their individual receipts.

The next prerequisite is an upstream supported bound/frontier implemented and published by HTTP Fetch, then a Gaoxy dependency update and renewed resource qualification. Issue closure alone is insufficient. Continuing development authorization is in AGENTS.md; Vault, release-artifact E2E, public management, production data and push/publication/deployment restrictions remain in force.
