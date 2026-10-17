# Managed-H1 matrix targeted browser source specification review5

**PASS_SOURCE_SPEC5** — no actionable finding in browser-only repair4. Direct independent read-only review. Candidate runtime **NOT RUN**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `1426657e65d726629d618dcf03880df718375dd1`, branch `codex/m3-h1-resource-foundation`.

Candidate5 SHA256 `5a8924e8d214d4b09c23a0bcf05b44012ae091d0ff2882128cbc1d4ab55dbba7`; inventory6 SHA256 `9b2f85aa0c6951e068d72a32ebc2cadf40dfdc55457d7d8c2073de96ea5d7a40`; browser.py SHA256 `c5251ea1d8847bc76c47275d3bce545961a2be7c1a17076293441479045d5713`. All9 owned/8 document/11 dependency current pins match. Both archived browser copies match their candidate pins; candidate5 archive=current source. Only browser.py differs in the401source maps; unchanged8sources retain prior independent reviews.

`browser.py:62-71,417-429` enables and verifies Linux child-subreaper status before Actor spawn. Actor partial ownership remains registered before log/spawn. `:165-188` reaps actual adopted children only after Popen has collected the named leader, using waitpid(-original_ownedPGID,WNOHANG). Actual PID/PGID/raw status/decoded exit/phase are retained. It does not wait globally or consume another active actor's named leader.

`:190-202` requires actual group disappearance within min(original10s,remaining20scase). Existing killpg0 presence checks remain; zombies are actually reaped rather than ignored. `:204-286` attempts natural leader/group join before force, then bounds TERM/KILL/reaping inside the original10s shutdown budget. Errors/forced/unjoined results still fail; other actors remain exception-isolated in the final sweep. Named actor exit0 and reader-thread joins remain required.

Independent AST checks passed without candidate imports/execution. All10 relevant top-level helper functions and5 existing Actor read/send/event/call methods are identical. All32 original require-call ASTs remain;3 additions require Linux, verified subreaper status and actual normal group join. The10/5/20/600 constants, page/body/protocol/readiness/SPKI/connection/completion/registry checks and unchanged Node/Chrome assertions remain. No all-OS-helper-exit0 requirement was added.

Original PGID is the narrow reaping boundary. A descendant-created new PGID/session is not proved absent; root outer adopted-child receipts remain visible and necessary. This source review does not infer process state before browser1 disposal or identify the unknown raw10 helper.

Retained final-nonbrowser-audit1 reports7commandsPASS,96ExUnit/Python11/standalone16 with324bodydescriptors under candidate4. This review read that audit without re-auditing unrelated logs. Browser1 remains overallFAIL/exit1 despite2rowPASS: final browser groups were forced/unjoined; the outer collector later reaped12raw0 and1raw10 adopted children before collector force. The source and canonical docs preserve that limitation. Candidate5 required syntax2/browser2 and4fresh rootimageopens remain NOT RUN. WholeTask6/Task5/M3 and final review/local commit/custody stay OPEN.

All finite static commands finished; no background process or candidate execution. Two oversized combined static displays were truncated and recovered with bounded projections; no source/runtime failure or repair arose. No repository edits or forbidden-scope access. Only these two requested `/tmp` reports were written. Ownership returns to root.

Counter18 handoff root510/orchestration409/tool20/groupfailedgreen68/runtimefailed2/Sol4/Astra2/2 remains unmodified. This review adds0repairs and reports2display incidents for parent custody. No product decision or escalation needed. JSON companion retains exact reviewed hashes and source traceability.
