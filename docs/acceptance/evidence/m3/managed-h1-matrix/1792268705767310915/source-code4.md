# Managed-H1 matrix targeted browser source code review4

**PASS_SOURCE_CODE4** — no actionable finding in the exact browser-only candidate4-to5 delta. Direct independent read-only review after PASS_SOURCE_SPEC5. Candidate runtime **NOT RUN**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; manifest baseline `1426657e65d726629d618dcf03880df718375dd1`, branch `codex/m3-h1-resource-foundation`.

Candidate5 SHA256 `5a8924e8d214d4b09c23a0bcf05b44012ae091d0ff2882128cbc1d4ab55dbba7`; inventory6 SHA256 `9b2f85aa0c6951e068d72a32ebc2cadf40dfdc55457d7d8c2073de96ea5d7a40`; browser.py SHA256 `c5251ea1d8847bc76c47275d3bce545961a2be7c1a17076293441479045d5713`. Fresh9 source/8 document/11 dependency pins match. Archived before/after browser copies match frozen pins; candidate5 archive=current source. Only browser.py changes in the401source maps. Eight unchanged owned sources retain prior source/implementation reviews.

`browser.py:62-98,417-429` verifies Linux child-subreaper setup before any Actor spawn. Existing partial Actor registration precedes fallible startup, and SIGALRM remains masked until process/thread ownership is retained. `:165-188` waits adopted children only after the named leader was collected by Popen, scoped to that Actor's original isolated PGID. PID/PGID/raw wait status/decoded exit/phase are actual wait results. Group disappearance remains required; zombies are not ignored.

`:190-286` keeps normal leader/group/thread joins within min(original10s,remaining20scase). Disposal allows natural collection first, then shares the original10s shutdown budget across TERM/KILL/reaping. Forced/errors/unjoined outcomes remain failing; per-Actor exception isolation still attempts the rest. Named Node/Chrome exit0 remains mandatory. No global wait steals another active Actor's leader.

Independent static AST checks retain all32 original require calls,10 relevant top-level functions and5 existing Actor bridge methods. Three new require checks cover Linux, verified subreaper and normal group join. Constants10/5/20/600 and page/body/protocol/readiness/SPKI/upstream/completion/registry assertions remain unchanged. No all-OS-helper-exit0 oracle or new scope requirement appears.

Original PGID is the local reaping boundary. Descendant-created PGIDs/sessions are not proved absent; the outer collector's live/forced/residue gates and actual adopted statuses remain necessary. No pre-disposal zombie state or unknown raw10 helper role is inferred.

Retained nonbrowser audit reports7commandsPASS,96ExUnit/Python11/standalone16/0 with324bodydescriptors under candidate4. This is separate from pending candidate5 browser qualification. Browser1 remains overallFAIL/exit1 despite2rowPASS/fourpages: both final browser groups were forced/unjoined. Its outer collector later reaped12raw0 plus1raw10 adopted children before collector force. Historical failures remain immutable.

Affected syntax2, browser2 and four fresh root image opens remain **NOT RUN**. WholeTask6/Task5/M3 and final review/local commit/custody remain OPEN. Root owns these gates; no unrelated nonbrowser repeat is requested.

No new tooling incident, repository edit, candidate import/execution or background process. All finite commands completed. Only these two requested `/tmp` reports were written; ownership returns to root. Handoff root510/orchestration409/tool20/Sol4/Astra2/2 remain untouched; SPEC5's pending2 display incidents stay for parent custody. This review adds0repairs/0incidents and requests no decision or escalation. Full hashes, static commands and line assessments are in the JSON companion.
