# Aggregate evidence-tool source review 1

Task `/root/browser_contract_spec/aggregate-review1`: **DONE — PASS_SOURCE_TOOL_ONLY**. Direct independent source-only review; no open actionable findings.

Reviewed `/tmp/gaoxy-group-final-aggregate1.py`, SHA-256 `79cd042ef372ab7867237bc0ac82d3d7f74300315a6aa188b8d12c66baaa0304`.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Historical supplied baseline: `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Frozen candidate `postactivation-full-review-candidate2.json`, SHA-256 `2429bbdecb1bba716627af84f24c59209a10d953f985acace590736978e0fb7e`, authenticates 198 source entries. Source identity is the manifest, not an inference from HEAD.

## Finding and closure

**AGG-TOOL-01 — CLOSED_SOURCE.** The original prefix selection admitted later receipts from different required gates: `fresh-session` also matched `fresh-session-control`, and `fresh-probe` also matched `fresh-probe-controls`. Latest selection could then fail the identity assertion. This was a false-rejection defect in an unexecuted scratch evidence tool, not a production defect or executed gate failure.

Parent corrected selection to an escaped exact filename fullmatch before timestamp filtering. Read-only Python syntax inspection and the 25-name matrix passed (exit 0): each required name accepts its own timestamped receipt and rejects every other required gate name. The final script hash above was independently confirmed after correction. No further actionable source-tool finding was identified.

## Source assessment

The script pins the candidate hash and checks all 198 current source hashes; binds adoption and all four source-review report hashes; authenticates the collector, required gate list, browser wrapper and ledger; requires 25 unique command gates; and selects exact-name receipts after adoption. Command receipts require exit 0, a joined process, no timeout, exact before/after source maps, source stability, collector identity, no unexpected warnings, zero failures/skips/exclusions, the zero-skip configuration declaration, and nonzero executed tests except format/compile. Log SHA and length must match.

Browser checks require a post-adoption receipt, exit 0, joined/no timeout, exact before/after source maps, stable sources, the authenticated wrapper, three completed cases and PASS. Log and qualification hashes must match; qualification must report PASS, three executed cases and stable sources. The authenticated canonical suite itself enforces the exact ordered three cases and three isolated browser joins. The output uses exclusive creation and retains historical negative cleanup, exhausted Astra counters and remaining closure/custody steps.

## Verification and limits

Read-only manifest/artifact authentication, syntax inspection and exact-name matrix checks passed. `sha256sum /tmp/gaoxy-group-final-aggregate1.py` passed with the final hash above. No aggregate execution, fabricated receipts, builds, tests, runtimes, process-control or Git mutations occurred in this review. The parent runner was left untouched. All reviewer commands have finished.

Fresh25 and canonical browser3 are **not accepted by this review**. After source review completed, parent reported fresh25 halted on native TLS (41 tests / 1 failure): the original positive H2 worker join received `:killed` at line 209. Parent reported receipt `fresh-native-tls-1792099204364786266.json`, SHA-256 `b39c05bca4f3192ad902c8f8ca12842264e7961e8ebe64481169f53b66ff21c9`, and a diagnostic-only follow-up. This reviewer has not independently authenticated that runtime update. This verdict covers source tooling only; it does not claim stage, runtime, publication or deployment acceptance. Historical cleanup remains `UNCONFIRMED_WITH_RETAINED_FAILURE`. The authenticated ledger8 snapshot records failed GREEN 20, ordered root events 23, Astra 2/2 exhausted; reviewer adds zero repair rounds. Parent subsequently reported failed GREEN 21 with no new repair adopted; that update is identified as parent-reported, not fresh reviewer authentication. Ordered events and repair rounds are distinct, and the scratch correction changes neither.

Reviewer wrote only this report and its JSON counterpart. Parent owns the scratch correction and subsequent receipt execution, documentation rebind, independent closure and commit custody. No new design decision or Astra escalation is requested.
