# Managed-H2 slow-peer design SPEC1

Verdict: **CHANGES_REQUIRED**, one actionable gate clarification. No other known protocol design blocker found in this bounded static review. Concrete-source CODE review and all runtime remain **NOT RUN**.

## SPEC1-01 — retain browser/default-startup regression gates (medium)

References: `AGENTS.md:72-73`; `docs/designs/m3-managed-h2-slow-peer.md:53-55`; `docs/plans/m3-managed-h2-slow-peer.md:41-46`; `docs/acceptance/m3-managed-h2-slow-peer.md:7`. The shared peer default paths are at `apps/gaoxy_proxy/test/support/managed_h2_fixed_peer.py:722-820` and `:968-1008`.

The design makes a browser row conditional on a browser slow-consumption claim, and the closure gates omit a fresh ordinary browser regression for the changed shared helper. Preserve the existing ordinary browser two-row/four-image regression and existing Python 11-method startup checks explicitly in the synchronized design/plan/acceptance. Bind actual results to final candidate bytes and retain normal joins and actual image opens. Label browser results as compatibility evidence; no browser slow-consumption claim/oracle or production scope expansion is required. Root has already authorized this clarification.

## Static evidence and limits

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; actual entry from E12 custody: `deef3b0f41b55d30d83fc615998c1fad16e7b4a4`. Candidate SHA256 `7425942b8d47b87ce7d9807dfc11020457ddba7c182cba8ae08e7c4631aaa256`. Fresh static checks matched all 25 current inputs and 8 documents. Exact E12 predecessor custody SHA256 matched `1d6e74e923e9f467ccdd7b140a4055760eabe381cde6651fc3df270aea5896f7`. Historical source-adoption pins precede the current upstream-plan overlay; this is not candidate drift.

The native source supports the proposed static queue bounds: `http2/connection.ex:708-728` limits pending DATA to one <=16,384-byte write per stream; `:843-848` bounds output; `:398-407` and `:736-778` track queued/delivered wire and return credit. Source supports the existing upload hold (`managed_h2_fixed_peer.py:315-328`) and strict default release (`:502-512`). The proposed opt-in resume/three-stream consumer remains new implementation. Actual Handler decoding, overlap, mailbox ceilings, queue pressure, source counts and finite timing require later concrete-source/runtime checks.

Review used static reads, JSON and SHA256 only. No Git, Mix, build, tests, browser, candidate imports/execution, protected E4 access, or repository writes. All commands finished. Four tool incidents: one absent guessed custody path, then three truncated displays; the exact custody path and relevant bounded source ranges were subsequently read. No runtime or repair failure occurred.

Counters preserved: entry root521/orchestration420/H1tool30/newslowTool1; inherited Sol4/Astra2/2 exhausted; new-profile Sol0. This review adds four tool incidents. No Astra escalation. Task6/Task5/M3 and separate open profiles remain OPEN.

Ownership returned to root. Only the two requested `/tmp` reports were written. Next review can be restricted to the gate correction and new candidate document pins.
