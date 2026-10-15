# Independent design SPEC readiness — managed H2 group boundary

Task `h2_group_boundary_readiness_spec`: **DONE** for independent design review. Verdict on the exact requested artifacts: **FAIL — four required design corrections remain**. This is not implementation review or implementation entry. The current source-foundation predecessor is still awaiting actual accepted local commit; preliminary tests and this review do not release successor entry.

## Reviewed identities and custody

* Design SHA256 `303d60c0a7ad06cab673349d4d0d6fc1e32ce5ff1e13e1313a8a09be1795e1c4`.
* Plan SHA256 `1615f67db7fe8a3288a66d2dd64409af37e48cf6b7ac0cb9de844fc2c693586f`.
* Decision SHA256 `0c4bf9f1503548710ca17f6f3cf47c134749c43166d0a11aa49f6aa42dd5b297`.

All matched supplied hashes before review/report. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, observed HEAD `192745a4104b65d84c8de05d0fefff19b4de90fc`. Root owns the existing source-foundation Envelope edit and untracked source test, all repository/index/runtime work. This reviewer authored none of these boundary design artifacts and changed no repository file.

## Required findings

### BP-SPEC-01: Upload PID is lost across the open-to-bind continuation

ManagedH2Client.open returns {:ok,original_handle,upload}; upload is PID or nil and is independent of handle.stream. Current Session retains upload only in open_selected local scope and passes it to ready immediately after bind. Proposed bind state has no upload field, request_options=nil and payload-free continuation, so streamed upload cannot reach ready.

Required correction: Use root-selected finite {:group_bind, upload} continuation payload, validate upload PID|nil before decision, preserve original handle unchanged, pass upload to ready only after both binds; remove no-payload rule for bind. Add pure result/carrier tests.

Evidence: design:44,53-60, plan:56,67,70-71; actual http/session.ex:221-242, http/session.ex:19-56, managed_h2_client.ex:228-237,295-301, http.ex:690-708.

Review-time decision: Root explicitly chose this carrier during review, but exact frozen design/plan remain unmodified. This does not amend or pass the reviewed hashes.

### BP-SPEC-02: Exact Selected member is discarded before the proposed boundary call

Owner returns exact id/config/max_inflight. Session.select currently passes only member.config to select_transport; handoff stores handle/config only; open_selected receives config only. prepare_group_open(state, selected, now) cannot validate original id/max_inflight or actual three-key Selected from these values.

Required correction: Specify exact H2-only member threading for direct and handoff paths. Root selected one member/config root in group-only awaiting_transport variant, not separate config plus duplicated selected.config. No global Session key. Preserve H2 config based on selected protocol/client before old state.client URI rewrite; invalid H2-group shape never falls through to legacy generic open. Freeze the exact pure helper return/error and result-decision tags and the third argument of group_open_result/3 before independent test/Session authoring.

Evidence: design:29-34,48, plan:53-56,68; actual upstream_groups.ex:666, http/session.ex:430-459,480-490.

Review-time decision: Root explicitly chose member threading/no duplicate config root; helper detailed result algebra is not yet in frozen artifacts. This does not amend or pass the reviewed hashes.

### BP-SPEC-03: Original lifetime/opening anchors and timer application need explicit placement

Current apply_limits reduces deadline using started_at+effective.max_lifetime and opening_deadline using activated_at+effective.opening_timeout, then resets both timers. Pure Boundary context has now/limits/deadline/opening_deadline but no original anchors; lowering effective limits alone cannot reproduce these absolute clamps. Recomputing from now would extend an already aged member budget; dropping the old generic open_selected call may omit apply_limits entirely on the direct path.

Required correction: Require original-anchor arithmetic in group Session path before building Boundary context: deadline=min(old,started_at+effective.max_lifetime), opening=min(oldOpening,deadline,activated_at+effective.opening_timeout), checked signed64 and cleanup headroom. Keep timer cancellation/rearming in actual callback outside pure state helper. open continuation recomputes remaining from those unchanged absolute deadlines, never refreshes from now. Add pure transition tests with aged anchors and smaller member limits.

Evidence: design:31-38,49-51, plan:41,53,68-69; actual http/session.ex:91-104,221-225,313-334, http.ex:498-499,690-708.

### BP-SPEC-04: Pure transport-order rejection has no authority/reference input

Pure prepare4 receives group H and one Selected, not the owner record/full ordered member set. Two unique permutations of H.transports can each be valid first-occurrence orders for different groups. It cannot determine which ordering was forged. Plan currently requires rejecting out-of-order transport list, conflating ordered shape with owner-record authority.

Required correction: Pure tests reject duplicates and invalid handles and preserve input order; no sorting or fabricated canonical order. Authenticate full ordered H by the future existing owner record equality, explicitly outside pure proof. Remove isolated out-of-order rejection unless comparing a second existing state alias with an already specified exact H, which proves only alias consistency.

Evidence: design:31-36, plan:30-34; actual upstream_groups.ex:120-142,185-213,557-562.

## Positive disposition and bounded constraints

* **OBS-01 — SOUND_BOUNDED_DIRECTION**: A pure prepare4 plus literal denial and actual guarded Session state transitions is a smaller useful dependency than detached all-phase transfer APIs. Four implementation/test paths are sufficient; no new process/dependency/HTTP admission/Options/owner/Probe/reservation/fixed projector work is necessary.

* **OBS-02 — CORRECT_IDENTITY_PRINCIPLE**: Selected protocol/client, exact selected T membership and normalized checked origin matching must precede preservation of raw selected URI. Current old state.client decides checkout URI rewriting, so a dedicated H2-group branch is needed. Marker/shape never proves owner or instance association.

* **OBS-03 — LIMIT_INTERACTION_CONFIRMED**: Upload may be reduced to min(endpoint/member max_chunk); source must first validate original compact Neutral. Existing prepare_group_request then preserves effective fields/pseudoheader checks. Ready must carry effective five limits so actual pump read_upload uses member-reduced chunk/write timeout; body_mode/content-length/header limits remain unchanged.

* **OBS-04 — CLEANUP_REQUIREMENTS_SOUND**: Drop before fail/settle must remove opening/selected/Neutral/K and submitted URL but retain original request/completion, transport/group tokens/pins, service token and managed_path. Existing bind transport-first and finish transport/pins→group→Service can be reused. Existing cleanup-unconfirmed stop/hold path and finite health neutrality remain separate from gate denial.

* **OBS-05 — GATE_SCOPE_SOUND_PENDING_CODE**: Literal activation denial is valid non-live scope control, not evidence of bounded live admission. Exact group-specific dispatch and unconditional gate dominance of every new open path require independent code review. No forged ready/accounting flag, helper result, public message or test adapter may invoke actual continuation. Queued cancel/DOWN pre-open handling remains a mandatory pre-activation obligation.

* **OBS-06 — FUTURE_OBLIGATIONS_PRESERVED**: Startup four-root and separate Probe/recovery shape/source/overlap proofs remain future consumer-wired obligations. No numeric9Q/8C/4K/2MiB/11542108 reserve is adopted; fixed9444956 remains unchanged.

* **OBS-07 — ADDITIONAL_COHERENCE_CONSTRAINT**: While threading H2 member, require same exact H in GroupEndpoint/selector/selection aliases before dropping them, and same exact selected T in selection/awaiting/transport_selection. Check selected raw origin length<=H.max_url_bytes as well as8192 to preserve advertised selected-origin bound; these checks establish coherence only, not owner authority.

The new pure module should still export only prepare/4 and activation/0. Preserve exact selected three-key member, exact six-key context, proposed exact eight-key H profile, finite fixed five limits, signed timestamps/deadlines and exact seven-key ManagedH2Client options; use accepted compact Neutral/config/checked validators and actual selected raw scheme/authority. No owner lookup, synthetic origin, caller-ready flag, detached startup/recovery constructor, test adapter, new process or generic accounting framework is needed.

Before independent Session/test authors start, freeze the corrected exact helper contract: prepare_group_open success/error/sanitized-state tags, drop_group_opening invalid/non-group behavior, group_open_result/3 arguments/decision variants, and {:group_bind,upload} carrier validation. A pure result helper can expose transitions for tests; it cannot grant runtime authority or invoke bind/open. Upload is PID|nil because current ManagedH2Client.create_upload returns nil for none/length0 or a PID otherwise; public handle.stream remains nil at open and cannot substitute for this upload.

For future actual readiness, source-linked tests must prove the corrected group-only routing rejects invalid group shape without falling through to fixed/H1 open, preserves exact group/T alias identity and original completion, and respects aged deadline anchors. Independent CODE must check real gate dominance and callback dispatch rather than brittle AST/source-text unit tests. Unchanged generic/fixed reachable clauses need the existing scoped compatibility evidence, with new results recorded rather than inferred from pure tests.

## Entry and result boundaries

Current source-foundation acceptance/commit: **PENDING**. Boundary implementation: **NOT RUN**. Boundary tests/format/compile: **NOT RUN**. Runtime/client.open/Fetch/group prepare/Probe/network/browser: **NOT RUN**. Accounting: **ACCOUNTING_NOT_READY**. Numerical hypotheses remain **UNPROVED_NOT_ADOPTED**. No new publication, deployment or external permission was used.

Root has selected bounded fixes for upload carrier/member threading; ask the design author to revise exact artifacts and re-freeze hashes, then obtain independent re-SPEC. No user product decision or new architecture is required. Do not mark this frozen review passing based on oral corrections or a future code review promise.

All source/read/report commands completed synchronously. No Mix, timer/process/peer/browser, network, model/agent, repository/index mutation or test execution occurred. Review repair rounds:0; inherited fixedSol19, fixtureSol20 RED1/GREEN1, collectorSol17, full58 failed2 and Astra2/2 remain unchanged. No escalation or third Astra recovery.

## Root-selected revision direction, not acceptance of amended artifacts

After these findings, root proposed the following precise helper algebra. Record it for the design author to adopt; **the reviewed hashes still FAIL**:

```elixir
prepare_group_open(state, selected, now)
# {:ok, staged, :group_open} | {:error, finite_reason, dropped}

drop_group_opening(state)
# group-only state -> dropped_state; exact legacy no-op/rejection policy must be frozen

group_open_result(state, result, now)
# {:ok, bind_state, {:group_bind, upload}} | {:error, finite_reason, dropped}
```

`now` is signed64 in both pure helpers, never a hidden clock read. Preparation computes per-key effective limits and original-anchor deadline clamps in pure state arithmetic. The actual callback cancels/rearms existing opening/total timers **once after success**, outside the pure helper; it must not both call side-effecting apply_limits and independently reset the same timers. Revalidate all relevant additions/subtractions and reserve signed64 cleanup headroom for deadline+1000. A pre-open continuation uses existing absolute deadlines, with no renewed lifetime/opening budget.

Current ManagedH2Client success is `{:ok, handle, upload}`. upload is nil for body :none/length0, otherwise the owned upload PID. Validate PID|nil; do not derive it from handle.stream (nil at open), alter the public handle, or insert a private upload field into it. The real original public handle is exactly promise/completion/stream/resolved; Promise has Task/completion and Task has owner/pid/ref/mfa. Use the existing pure public ManagedH2Client.completion(handle) validity/identity contract (non-nil exact RequestCompletion shell) rather than accepting an arbitrary map. This is shape validation only and confers no runtime/completion provenance. Preserve the exact original value in both state.request and state.original_request.

Error decision semantics need explicit text before test authors freeze expectations. Preparation/local gate/deadline errors use fail/settle with neutral/cancelled passive health, not upstream_fail. Ordinary attempted open errors use the existing normalized upstream mapping. **Classify cleanup-unconfirmed before collapsing arbitrary error diagnostics**; retain an explicit finite cleanup-unconfirmed discriminator (or callback inspection of the original result) so the existing transport_selection-specific stop/fail/hold branch survives. Do not erase that distinction into generic upstream_failure before dispatch. In every error return, dropped state keeps existing original_request/request, transport_selection/pins, group selection, service cleanup token and stable H2 managed_path. No fake completion, extra handle field, early refund or bind is performed by the pure helper.

The above algebra is a feasible bounded recommendation based on actual Session/client code. It is not an oral amendment accepted by this review. The revision must settle exact finite error tags and non-group drop behavior and then undergo independent re-SPEC against new hashes.
