# Independent revised design readiness SPEC2

Task `h2_group_boundary_readiness_spec2`: **DONE**. Verdict: **PASS** on authenticated candidate SHA256 `cee3d3788d986f2b5e4022ce44914b8f4902a0c8d8bc0e32b9812a0ba5849c82`. No implementation-critical unresolved findings.

Reviewed worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; verified HEAD `060f92641ae12345b7121e220549222418a40b0e`. This is an independent review of the revised written contract, not implementation or runtime acceptance. Root retains all repository/index/runtime/evidence ownership.

## Custody

All 18 source hashes, all 11 evidence hashes and all 11 evidence byte sizes match `docs/acceptance/evidence/m3/managed-h2-group-opening-boundary/1792066597490227419/design-readiness-candidate2.json`. Rechecked the complete manifest and HEAD immediately before producing this report. The three adopted document hashes are:

- `docs/designs/m3-managed-h2-group-opening-boundary.md`: `2b5f4d798a3274e88be49852167b3ec6c0782edd7d45905e5e592a2b813a9e4a`.
- `docs/plans/m3-managed-h2-group-opening-boundary.md`: `f2db5652cb8bcd6646926c1e043b4e400a1f3d7fd7e7164f008bc8bfee9d204e`.
- `docs/acceptance/m3-managed-h2-group-opening-boundary.md`: `262abe88fa81aace6f9e09368fd0e52ae7392783db343174e1f3cfb753f36ba5`.

The boundary implementation file is absent. Existing predecessor documentation edits and untracked root evidence were observed and left untouched. The initial failed SPEC and wrong-path custody diagnosis remain bound historical evidence.

## Prior findings

**BP-SPEC-01 — CLOSED.** Exact result algebra carries PID|nil in {:group_bind,upload}, independently of handle.stream, and preserves the original handle. Ready follows transport and group binds. References: design:48-58,78; plan Tasks2/4.

**BP-SPEC-02 — CLOSED.** Exact three-key Selected is threaded through direct/handoff/checkout; awaiting has handle/member only; H2 checkout preserves raw selected origin and returns Selected. The third now argument and every pure helper result are frozen. References: design:21,33-37,41-58; plan Tasks2/3.

**BP-SPEC-03 — CLOSED.** Pure arithmetic uses started_at and activated_at, checks signed arithmetic and cleanup headroom, and preserves reduced absolute deadlines. Actual callbacks install timers once per required transition; continuation only recomputes remaining intervals. References: design:25,62-72,76; plan Tasks2/3/4.

**BP-SPEC-04 — CLOSED.** Pure checks accept either otherwise coherent unique supplied order, reject duplicates/invalid handles, preserve order, and leave actual ordered-H authentication to full owner-record equality. References: design:23,37; plan Task1.

**OBS-07 — CLOSED.** Raw root is bounded by H.max_url_bytes and8192; existing H aliases and selected-T/awaiting/transport-selection/pin aliases must match exactly. These checks explicitly establish coherence only. References: design:25,35-37; plan Tasks1/2/3.

## Additional contract checks

The exact Selected/context/H/options schemas, checked protocol and normalized-authority comparison, raw root assembly, original Neutral validation before upload reduction, coupled manifest bounds and five effective limits are consistent with the accepted Envelope and current client facade. These checks confer no runtime authority.

Group-only classification is explicit before legacy fallback. Valid sanitized group states retain selection H, allowing idempotent cleanup; malformed group payloads are stripped, and non-group/fixed/H1/H3 drop remains identity. Pure helpers leave timers untouched and real callbacks own required timer updates.

Result success preserves the actual original public handle, validates its supported completion facade and carries upload separately. Late successful open retains the original completion before deadline/cancel rejection. Invalid success takes explicit cleanup-unconfirmed invalid_response without fabricating a completion or retaining a malformed handle. The accepted client constructs only PID-or-nil upload. No live provenance is inferred from pure fixtures.

Raw cleanup-unconfirmed atom and tuple are classified before generic finite normalization; the finite discriminator reaches the transport-selection-specific branch. Existing UpstreamTransports.finish on an unbound completion returns cleanup_unconfirmed and retires the resource without removing its hold (upstream_transports.ex:438-439), supporting conservative cleanup. Local preparation/gate/deadline errors retain neutral health while attempted client failures use existing upstream_fail. Bind/cleanup order and selection/pin/service ownership remain explicit.

No new implementation-critical contradiction was found. Actual Selected threading, H/T alias validation, H2-specific checkout, timer placement, gate dominance, continuation dispatch, upload-to-ready and cleanup normalization still require direct independent code review and fresh scoped execution after implementation. No AST/source-text test substitutes for that review.

## Entry and acceptance boundaries

The source-foundation local feature commit exists at the verified HEAD. Its final documentation closure is **PENDING in the frozen candidate** and was not accepted or independently reclassified by this review. Boundary implementation entry requires that closure as well as this revised design PASS. Original SPEC1 remains FAIL as historical evidence.

Boundary implementation, tests/format/compile, Session/owner/Probe/client.open/Fetch, network/browser, accounting qualification and publication/deployment: **NOT RUN by this reviewer**. R-GROUP-ACCOUNTING remains **ACCOUNTING_NOT_READY**; literal activation denial is required. 9Q/8C/4K, extra2097152 and total11542108 remain **UNPROVED_NOT_ADOPTED**; fixed9444956 is unchanged. Future startup/source/overlap, Probe/recovery, admission, queued-cancel/DOWN and real protocol acceptance obligations remain intact.

## Scope, counters and command closure

Only the two assigned `/tmp/gaoxy-h2-group-boundary-readiness-spec2.{json,md}` report files were written. No repository or index edits, runtime/test/network commands, agents, commits or publication occurred. All own read/report commands completed synchronously with exit0; no persistent command was started.

Boundary counters remain design failedSPEC1/custodyfailure1/implementation0/repairSol0; revised SPEC2 PASS does not erase failure evidence. Source-foundation repairSol1/failedSPEC1/custodyfailure1/intendedRED1/unsuccessfulGREEN0 and earlier fixedSol19, fixtureSol20 RED1/GREEN1, collectorSol17/full58 failed2 are inherited unchanged. This review starts zero repair rounds. Astra2/2 remains exhausted; no escalation. No user design decision is needed.
