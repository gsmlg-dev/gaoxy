# Managed-H1 matrix predesign SPEC review

DONE — direct independent read-only specification review. Recommendation: **APPROVE_PREDESIGN**, with **no actionable findings or necessary specification corrections**. This approves the bounded proposed design/plan, not implementation or phase acceptance. Materialization and execution must wait for the parent-owned downstream-cancellation candidate to pass its prescribed gates.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Parent-provided baseline: `e40284971ac1df030ef8bcb46e07b0b3838a3c53`; not independently Git-verified because Git was prohibited. No repository edits or current cancellation/new4 review. All planned 16 cases, runtime, integration, browser and stage acceptance are **NOT RUN** by this assignment; executed runtime tests 0. Task6/Task5/M3 remain OPEN.

## Findings and scope

No blocking, major, medium or minor findings. No new upstream issue, product decision, dependency repair, proof gate or scope expansion is needed. The proposal implements a cohesive managed-H1 part of Task6: fixed/group x native cleartext H1/prior-knowledge H2 downstream x TCP/TLS-H1 upstream, two families per each of eight rows. It preserves existing upstream-H2, generation/identity and deadline coverage without claiming that this new runner executes it. Independently slow-peer/queue/reservation/sibling qualification remains a separate substantive boundary.

The real protocol roles are feasible with the named current sources: the Python client sends/parses actual downstream H1/H2; the raw TCP/TLS-H1 peer observes upstream socket bytes independently of the SUT parser. The shared support fixture is proposed new test-owned code, with explicit lifecycle; private helpers and ExUnit test modules are not treated as reusable public APIs. Reuse of patterns and the existing client is sufficient; no second client/protocol framework or old-suite refactor is necessary.

The specification already addresses the meaningful pitfalls. Existing H1 Content-Length reads wait for the entire body, so opt-in prefix observation must read only to the threshold before waiting for the remainder. H2 prefix receipts must account for terminal events in the same receive batch. Existing group peers classify every HEAD as health, so the new fixture must classify target/role and retain application HEAD. The persistent raw H1 HEAD->204->GET subcheck detects framing that the existing Python HEAD shortcut cannot. The original request/completion/binding comparison avoids mutable whole-state equality and the H2-only submitted_url clearing transition. Exact gzip bytes, ordered duplicates/trailers and actual accepted upstream connection IDs meet the proposed representation/reuse contract.

The lifecycle contract is appropriately finite: explicit start/stop; bounded absolute barriers and case/startup/shutdown/overall budgets; immediate peer failure/exit propagation; failure on missing/duplicate/zero cases and wrong identities; caller-owned cleanup; joined accounting; forced cleanup visible and unable to satisfy normal PASS. During implementation, apply that same cleanup contract to partially completed startup as well as successful start. This is an implementation reminder within the existing contract, not an additional finding or gate.

## Verification basis and limits

Read Task6 at `docs/plans/m3-upstream-transport.md:667-695`, the complete two proposals and preparation/coverage reports, plus the narrowly identified current raw-peer/client/lifecycle/bodyless/policy sources. Exact 14 current input hashes and read scopes, eight source-review assessments, and expected proposal-hash matches are in the JSON. Hashing full files does not extend the inspected source ranges or review the parent's new cancellation cases. No historical runtime receipt was audited. The parent must freeze the actual candidate/evidence identity after the current gates pass.

Design SHA256: `1feb4ada243a0815f63d820e7cf6ed700358b3f39c79347f9924408700191e70`.
Plan SHA256: `7a8ab9d5818b63dbe083a7a29ae6110c05d5e953b750751a983cb7a8bf911e3f`.

## Incidents, ownership and shutdown

Two tool-output events clipped: the first aggregate proposal/coverage read, and the later combined source-read output. Full proposal numbered reads, compact JSON inspection and bounded relevant source/CLI reads recovered the needed content. No command exited nonzero; no test/product failure was observed or inferred. These are this review's incidents, separate from input reports' earlier incidents.

Only `/tmp/gaoxy-managed-h1-matrix-predesign-spec1.md` and `.json` were written. No Git, tests/build/runtime/browser, delegated agents, upstream issue, repository inventory, protected E4 file access, raw traces/NetLogs/keys or account mutations. All commands finished; no owned processes/listeners were started. Repair delta: Sol 0/Astra 0. Received Astra recovery counter 2/2 exhausted; prior cumulative Sol counter not supplied and not reset. No escalation; no external decision needed. Remaining risks are unexecuted implementation/runtime gates and parent source drift before freeze.
