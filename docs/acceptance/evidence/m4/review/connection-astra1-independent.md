# Independent bounded Astra1 recovery review

Reviewer `/root/m4_spec_review`, 2026-10-12, `.trees/m4-http3`,
`codex/m4-http3`, current HEAD `2b4a5e5`, original baseline `78de9d0`.
Reviewer authored the prior Sol Connection implementation; this independent
review covers Astra's recovery delta, its new regressions and execution evidence.
It does not represent independent authorship review of the reviewer's original
Connection code. Parent owns the overall G1 source review and final fresh gate.

## Specification compliance: PASS

Read `astra1/entry.json`, before snapshots, `repair.diff`, `red-command.json`,
`red.log`, `commands.json`, `units.log`, `format-check.log`, `compile.log`,
`validated-source.json` and the complete minimal runner summary/raw peer logs.
Every recorded current input hash matched the checkout. Intended regressions
failed **12 tests / 2 failures**, then passed **12 tests / 0 failures**; exact-file
format check and warnings-as-errors compilation exited0. The source-bound full
minimal runner recorded **47 PASS checks**, no failure, all5 owned child exits0.
This reviewer inspected those receipts rather than rerunning the author-owned gate.

The narrow first-terminal-decision guard now preserves the existing cancellation
commands, original deadline and unresolved operation reference when a reflexive
peer STOP/RESET arrives. The unchanged whole-state regression preserves siblings
and zero output, including an already admitted RESET plus uncertain STOP tail.
Both STOP callback and RESET read-item paths use the same helper. A local critical
control STOP still closes with H3_CLOSED_CRITICAL_STREAM, and a first peer
cancellation retains its original directional behavior.

The separate unchanged-server qlog diagnostic proves correct RESET+STOP0x10e wire
frames even when a FIN-completed peer stream suppresses its STOP callback. The
repaired independent harness preserves exact FIN RESET codes; five open-direction
cases require both exact RESET+STOP codes. Every stream error requires same-connection
sibling completion, connection-open scope and no DATA growth after reset. Underflow
retains FIN. No original timeout, malformed input or historical failure was removed.

Full-gate receipts include311296 echoed bytes under2048/4096-byte receive windows,
definitely blocked telemetry followed by byte progress, ordered trailers, HEAD,
CONNECT501, request-before-SETTINGS, independent static/Huffman fields, exact
control/QPACK/error scopes,5127ms incomplete-discard closure within6000ms,
cancellation0x10c with zero late DATA, live listener removal with Admission gate
DOWN and same-port rebind, established sibling completion, and bounded runtime
stop with both ports rebound and all captured gates DOWN. Timing is scoped to the
recorded run, not a general latency guarantee. No unresolved recovery-spec findings.

## Code quality: PASS

The recovery changes one shared cleanup guard and two focused deterministic
regressions. It does not alter frame/parser assertions, stream ordering, public
interfaces, dependencies, host ownership or authentication policy. The guard
prevents replacing the original error code, requeueing an admitted reset and
losing an uncertain cleanup reference; it preserves existing siblings wholesale.
No broad server reorder or dependency workaround was introduced. No unresolved
code-quality findings remain for the Astra recovery delta.

Cumulative Connection counters remain **Sol2 / unsuccessful2 / Astra1**. The
successful recovery does not erase earlier failed attempts. The controlled
unknown-operation injection remains NOT RUN; map/ref/deadline preservation was
covered deterministically, while normal real-peer admission/blocked observations
remain separate from peer byte delivery. G1 is the bounded fixture profile;
shared Endpoint/Plug, browser/proxy/upstream/standalone, hosted CI, publication
and deployment are not qualified by this receipt. Reviewer owns no running
commands; source/Mix lease is released to parent for fresh verification.
