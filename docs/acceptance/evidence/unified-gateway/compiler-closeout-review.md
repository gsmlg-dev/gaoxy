# Independent compiler closeout evidence review

Task: unified-listeners-embedded-gateway / core_lifecycle final evidence consistency.
Assignment: direct read-only review; this audit file is the only edit.
Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/unified-gateway.
Exact runtime source: d206e55de1696a8801a1cd64d80c7b903671641a, branch codex/unified-gateway.

## Verdict

PASS, no actionable discrepancies in the acceptance text, final source/package copies, checksums or compiler review. Parent-owned documentation/evidence edits were preserved. No root Mix command or source edit ran during this review.

## Checks actually performed

- Read current docs/acceptance/unified-listeners-embedded-gateway.md and .audit/unified-elixir120-review.md, final JSON copies, source identity and git diff/status.
- Validated all 43 archived SHA256SUMS entries against actual file bytes. All 32 original checksum entries retain their original digest; 11 added entries qualify the compiler followup/final source.
- Confirmed original source-inputs.json and package-receipt.json remain byte-for-byte equal to committed d206 source versions. Final receipts also retain and correctly match the original manifest/receipt hashes.
- Confirmed source-inputs-final.json and package-receipt-final.json are exact copies of .audit/unified-package-final outputs; both identify full source d206e55de1696a8801a1cd64d80c7b903671641a. Manifest/receipt counts are 157 packaging inputs, five archives and 122 runtime payload files. All 157 current input hashes match. Final receipt's source-inputs hash matches the archived final manifest.
- Confirmed exact-committed.log.gz decompresses byte-for-byte to the executed .audit/unified-exact-committed.log. It identifies REPAIR_SOURCE d206e55de1696a8801a1cd64d80c7b903671641a and ends REPAIR_PASS 265 executed, 0 failures, 0 excluded, 0 skipped.
- Confirmed package-build-final.log.gz decompresses to the actual final build log; archived elixir120-review.md exactly equals the independently authored review. Review accurately preserves the original Elixir1.20/macOS strict-warning failure, two-line compiler fix, local20/0 scope and requirement for a fresh hosted outcome.
- Read hosted-initial-summary.json: source14c5fd91, native_http/Linux/optional-quic/isolated-network success and macOS1.20 failure. Acceptance does not promote this prior-source evidence to corrected-source hosted success.
- Acceptance explicitly states corrected-source hosted verification pending, coordinated publication NOT RUN and deployment NOT RUN/outside task. It states local1.18 evidence is not hosted1.20 success, links immutable originals separately from final157/122 receipts and records d206 exact265/0 without rewriting old failures.

The final package archive comparison remains as previously verified: four archives byte-identical to originals; only Proxy changes, with gateway.ex its sole changed runtime payload. No changed declaration/API/test or warning-suppression claim is introduced by the compiler closeout.

## Status and limits

DONE for this bounded evidence review. Static consistency command exit0; all own commands finished. Only this .audit report was written. Sol repair increment0; parent-owned cumulative counters unchanged; no Astra gate/counter. No commit, push, publication or deployment performed. Remaining external status is correctly pending and must be updated only from actual corrected-source hosted/publication results. No new decisions needed.
