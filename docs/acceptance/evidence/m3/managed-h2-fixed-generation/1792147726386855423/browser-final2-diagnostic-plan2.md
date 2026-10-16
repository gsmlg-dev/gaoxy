# Browser final2 target-close diagnosis

Status: root cause UNPROVEN; diagnostic acceptance unchanged. This document is
an additive bounded diagnostic design/plan, not a production repair or stage
acceptance. Baseline aa272c3d, HTTP0.21.10/lock unchanged.

## Evidence and hypothesis

Final2 h2→h2c PASS; old h2→TLS-H2 visible document PASS then exact genuine target
connection350/writer355 had died before request_clean. H1 rows NOT RUN. Actual
terminal peer_closed follows the TI remote socket-close path; worker357 normal
DOWN and writer stop alone cannot prove a worker-DOWN production bug. Current
Cohort1 does not trace stream-done/socket-close/h2_close or peer frame processing.
The single diagnostic question is whether a prior server protocol frame/error
caused peer closure, or whether the peer closed for another concrete reason.
No production fix is justified before this is resolved.

## Minimal diagnostic adaptation

1. Preserve host2/runner2/Cohort1 and every original receipt. New host3 only binds
   new Cohort2 and correct diagnostic-source comments. Cohort2 adds VM-filtered
   finite h2_stream_done, ssl_closed/tcp_closed and h2_close projections. No
   socket payload/state/spawn args/call tracing. A receive projection attests
   receipt only, not execution of an application branch.
2. New runner4 retains all navigation, document, accounting, target-live,
   request_clean, explicit-close, actor/descendant joins and finite deadlines.
   Only diagnostic delta: root-owned temporary Chrome NetLog and safe bounded
   projection at each completed probe plus final actor disposal. Persist only
   whitelisted event/source/dependency/finite numeric-or-enum protocol fields;
   never URL/header/cookie/certificate/debug strings/raw socket bytes. Raw log
   lives outside repository and is removed after projection and actual group
   joins. If any Actor disposal cannot prove group/reader joins, retain the
   exact owned directory with a path/PID-only custody receipt. Root removes it
   only after the collector proves all owned group/descendant joins. Cleanup
   failure remains failure; no tempdir finalizer may remove a live writer's
   raw file. No capture-mode expansion or Chrome behavior-tuning flags.
3. Root joins formatter/syntax verification, binds exact immutable copies and
   reports, then independent diagnostic SPEC precedes CODE. Root executes the
   existing qualified browser command collector with unique diagnostic names;
   collector remains unchanged and retains actual command/source/join custody.
4. Interpret actual protocol metadata before selecting repair. If failure does
   not recur, diagnostic PASS is still not proof of root cause. If metadata
   remains ambiguous, use a second explicit bounded scalar call projection;
   do not blindly rerun or weaken target-live/discard extra Chrome connections.
5. Any proven repair gets its own written change, independent review and fresh
   required gates. Charged production constructor/lifetime changes reopen
   independent constructor SPEC then CODE. No third Astra;2/2 exhausted.

Counters at source2 diagnostic binding: group failedGREEN45/root63, stage
failedGREEN4, fixture repairs3/production0/orchestration4. Diagnostic SPEC1
found unproven-join raw cleanup ordering; revision2 fixes only that diagnostic
custody. Original browser cause remains unproven, with no runtime repair yet.
Instrumentation alone is not a repair. Historical final-stage SPEC/CODE PASS,537/0 and isolated-consumer PASS
remain valid only for their exact original source. Stage and whole M3 incomplete.
Root owns repo/runtime/evidence/Git; delegates own assigned /tmp reports only.
No publication/deployment/Vault/production/public-management/certificate changes
or disabled release-artifact E2E. Preserve unrelated prompts and prohibited raw
historical trace boundary. Do not revive dismissed http_fetch97.
