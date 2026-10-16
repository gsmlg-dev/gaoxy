# fixed_generation_browser_diagnostic3_spec1 — FAIL

Direct read-only independent diagnostic SPEC review. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `aa272c3dca700a9275a00bd23920d09bbd4748a1`. Frozen candidate `browser-diagnostic3-candidate1.json` SHA256 `7103057d22847a45ed5f3d0443dac68b6bc68c7886f0a734b1669391e0cb926a`.

## Actionable finding

**SPEC-DIAG-1 / P2 — final raw-NetLog projection/removal runs without proved joins on cleanup error.**

In E2 `fixed-generation-browser-runner3.py:621–629`, an `actor.dispose()` exception is caught and recorded as cleanup_failed. Such an exception can mean owned process-group disappearance was never established (`Actor.dispose:386–390`), or process wait failed. Nevertheless `:630–635` always runs final `write_netlog_projection` and `diagnostic.cleanup()`. Chrome may still be alive and writing, so final projection races the writer and temporary raw-log removal occurs before actual group joins. The later FAIL at `:636–639` does not repair that ordering. This violates explicit diagnostic-plan1 step2: raw removed after projection and actual group joins.

Required change: gate final projection/removal on proved termination of every raw-log writer's owned group; on unproven join, keep exact task-owned temporary directory with explicit ownership/failure receipt for root/collector cleanup after actual joins. Do not use an implicitly finalized TemporaryDirectory that later deletes the unjoined writer's file. Normal groups and forced-but-proved-joined groups can still project and remove immediately. Preserve all original failure classification, assertions, finite deadlines, and actual exit evidence. This is diagnostic custody repair, not a diagnosis/fix of the original target close.

## Confirmed scope and retained specification

- Read diagnostic plan1, complete new host3/runner3/Cohort2 and full deltas against immutable host2/runner2/Cohort1. Verified all400 source manifest entries relative to repository and242 evidence entries relative to E2, zero missing/mismatch; repeated the entire hash check immediately before report. Candidate SHA matches assignment.
- Host3 differs only in Cohort2 require/identity paths and diagnostic comment. Original T8 source/child provenance, native B/W/95-row equations, CAS/retirement/Session/completion custody, genuine target-live checks, and all finite deadlines are unchanged.
- Runner3 preserves88 original Python AST Assert nodes exactly in order. Actor, assert_capture, adopted_children, reap_adopted, event_one_of, certificate_spki, inventory, and main are AST-identical. Embedded browser adds NetLog path/default-mode flags only; DOM/protocol/status/screenshots/explicit close/custody gates unchanged. No browser tuning, ignored preconnect, added retries, or production repair.
- Cohort2 adds only finite allowed done outcomes, socket-close tag with identity omitted in persisted fact, and h2_close metadata. Original census, authenticated Gate sequence, monitors, trace-delivery barriers,2048-event/128-actor/128-cut bounds and90s observer lifetime remain unchanged. Receipt is correctly documented as receipt, not callback execution proof.
- NetLog projector reads at most8MiB+1 and scans at most8192 events. Persisted fields are event/source/dependency ids and bounded numeric/boolean/enum protocol metadata. No URL/header/cookie/certificate/debug string/raw socket payload is copied. Partial/missing captures remain explicit and cannot prove absence. Normal cleanup path correctly projects/removes after proved Actor group joins; the error branch above is the only actionable delta finding.
- Compared final-stage candidate2 source manifest: no production/config/dependency/script source changes. Five canonical factual docs changed; three diagnostic source copies added. Full-stage SPEC/CODE records remain their exact historical evidence and this bounded review does not supersede them.

## Execution and ownership

Read-only Git identity/status, rg/cat/sed/nl, Python AST/diff/hash checks. All own commands returned; no build/test/application/Chrome/network/Git mutation/background process. No prohibited raw historical trace accessed. Existing workspace modifications preserved. Only assigned `/tmp` reports created. No tests were run or claimed.

Received cumulative counters45/root63/stage failedGREEN4/fixture3/production0/orchestration4/Astra2/2 exhausted; no counter reset, repair-validation round, Astra routing or runtime attempt by reviewer. No external/product decision needed. Diagnostic candidate FAIL until finding addressed and fresh bounded SPEC/CODE completed. Original target-close root cause remains UNPROVEN; stage and whole M3 remain incomplete.
