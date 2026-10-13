# M4 UP2 outstanding-operation cleanup implementation plan

Root owns apps/gaoxy_proxy/lib/gaoxy/proxy/http3_session_client.ex and its matching
test. Independent Sol owns unique review receipts. Other workers own separate
test-contract files; preserve their edits. Root serializes Mix/live/format/compile
and freezes all source while runtime executes.

- [x] Independent SPEC review of [design](../designs/m4-up2-inflight-cleanup-abort.md),
  source race and explicit failed-run causal uncertainty.
- [x] Deterministic held-public-call regressions: exact advanced Session to one
  terminal abort, stale result rejection, no late application delivery/replay,
  unknown operation abandonment, unchanged original stop_due/deadline, fallback
  and caller loss. Observe genuine RED; do not count TDD as another live failure.
- [x] Minimal same-caller cleanup scheduling after an outstanding result, within
  the existing100ms bound. No new operation overlap, process or deadline.
- [x] Focused GREEN and relevant scoped compatibility/format/strict builds;
  independent CODE/prelive review and immutable source/log/count/exit receipts.
- [x] Full68 matrix GAOXY_UP2_REPAIR=12 GAOXY_UP2_FAILED=20. Preserve all original
  cancellation/sibling, window, bytes/hash/FIN, deadline and zero cleanup oracles.
  After actual PASS require independent evidence review and fresh complete68
  repeat, then all final M4 source/Session/host/browser/standalone/consumer gates.

Current unsuccessful UP2 counters20 live/8 production/3 harness; earlier snapshots
are preserved. Ordinary diagnosis/repair remains authorized, no third Astra.
All prescribed implementation executions PASS; [the final ledger](../acceptance/m4.md#final-implementation-gate-ledger--2026-10-13)
links first/fresh68 matrices, both independent reviews and all final gates.
- [x] Final independent M4 acceptance/documentation review PASS. Portable artifact
  and offline runtime qualification and publication remain separate, NOT RUN.

Final M4 implementation acceptance: [independent review](../acceptance/evidence/m4/upstream-matrix/review-m4-final-implementation-candidate-acceptance-1791858009332797257.json),
PASS with no unresolved findings. Portable qualification/publication stay separate.
