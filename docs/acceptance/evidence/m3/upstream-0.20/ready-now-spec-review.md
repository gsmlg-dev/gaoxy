# Ready-now Tasks0–2 independent specification review

Reviewer: direct Sol `m3_public_client_audit`; not the probe, peer, adapter or architecture author. Workspace `.trees/m3-gateway`, branch `codex/m3-gateway`, baseline `d92d3691e073fbf33195b567af7be10cea6132fc`. Read-only; no reviewer runtime tests, edits or commits. Runtime checks were executed by parent.

## Initial reviewed outcome

**Implementation specification PASS for ready-now Tasks0–2. Final documentation/coverage clarification pending at this review.** This does not accept conditional Tasks3–8, managed transport activation or full M3.

Checked all seven installed packages/checksums, 187 installed-file hashes, 180 recorded Git blobs, strict upgrade compatibility460/0 seed161790, positive public requests16/16 and16 confirmed peer exits/zero live threads. Public H1/TLS H2/h2c probe assertions satisfy the plan. Task2's bounded execution/public cleanup PASS while memory reproduction remains INCONCLUSIVE; only2/4 deltas reach the unchanged preset criterion. No retained-bound PASS is justified.

Source-based upstream Bug routing is warranted: `connection_owner.ex:1006–1019` appends one retained list element per empty nonterminal fragment while guarding only payload-byte sum. Request duration is not a hard metadata cap. Describe measured memory as inconclusive. An optional final END_HEADERS/exact-body completion would prove consumption of preceding frames, not sample-time consumption or unique attribution; it is not required for the source-based issue.

## Findings and parent resolution

1. Initial201 source maps omitted `pooled_completion_probe.exs`, the direct probe and diagnostic helper. Preserve maps honestly and bind the executed probe. Its reviewer-observed hash is `f681723ff58754cb6169d0b42fb681a8439eeaa6c7ec7e94c752894405ce1e30`. Parent corrected the snapshot coverage and reran both unchanged probes with202-file before/after maps: `public-probes-final.json` session56048 PASS16/16; `empty-continuation-final.json` session16352 INCONCLUSIVE with confirmed cleanup. `source-coverage-correction.json` retains original scope limitation. No assertions/thresholds changed.
2. Update stale pending wording/checklists and link results while retaining #78/full-M3 BLOCKED. Parent completed current status/Task0–2 execution checkboxes and routed independent source Bug#79, typeBug/internal request/blocker, with original INCONCLUSIVE evidence and callsite TODO. Conditional Tasks3–8 remain unchecked.

Review repair rounds0. Task1 counters remain Sol2/unsuccessful2, Astra1/unsuccessful0; Task2 runtime repairs0. Source-evidence coverage correction is tracked separately. Previous Task5 Sol4/unsuccessful2/Astra2/unsuccessful1 remains unchanged.

## Final documentation and coverage re-review

**Final specification/evidence PASS**, direct Sol `m3_public_client_audit`, two findings resolved, zero new blocking findings. Independently checked both corrected202 maps include all executed scripts and match before/after,16/16 public cases and16 stopped peers, final INCONCLUSIVE diagnostic with2/4 qualifying deltas and confirmed cleanup/reset/shutdown. Verified Bug#79 type/label/blocker/requester/reproduction/runtime caveats and both adapter TODOs. Current wording/checklists match actual scopes; conditionalTasks3–8 remain unchecked, activation/fullM3 BLOCKED.

Reviewed design SHA256 `67d4c780adbcd45b39608d1915f14c8b19115749d7916b92d99a07fc1d2bc23a`; plan SHA256 `8e2ab493e4c7856ac830c8f3c93cc68a9924bb72173db5db420c87837f4e7834`. The sole source drift after public probe maps is the later adapter TODO#79 comment. Removing it exactly reproduces the recorded adapter hash; no runtime drift. Parent final18/0 format/compile receipt captures the added comment's delivery identity. No reviewer edits/runtime tests; read-only commands finished. This section transcribes the reviewer's final handoff.
