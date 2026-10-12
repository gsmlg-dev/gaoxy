# Task 2 bounded Astra recovery 1

Task `m4_task2_connection`, implementation recovery, gate
`SOL_REPEATED_FAILURE`; two unsuccessful Sol repair-and-full-validation rounds
are preserved in `../handoff.md`. Entry baseline is
`2b4a5e58bf3044baf289c266b96ee9a979f61309`, `codex/m4-http3`.
`entry.json` records pre-existing edits and input hashes; `*.before` preserves
owned inherited files. Root and peer edits remain untouched. No commit,
publication, dependency mutation or runtime deployment occurred.

## Diagnosis

The historical duplicate-pseudo timeout was an invalid peer observation
requirement. Independent unchanged-server probe
`../../peer-diagnostic/run-1791781331053387233/summary.json` observed both
RESET_STREAM and STOP_SENDING with exact 0x10e on the wire for an already-FINed
request, but aioquic exposed only RESET after ten seconds. With its request
send direction open, both exact callbacks arrived in 28 ms. Both probes kept
the connection and siblings alive with zero response DATA. The independent
peer author corrected FIN/open observation cases while preserving exact codes,
scope, sibling continuation, no late DATA, and the original finite deadlines.
No dependency defect or server operation reordering was justified.

A separate, deterministically reproduced Gaoxy defect existed:
`handle_event({:stopped,...})` and reset read items called `Protocol.reset`,
which emits a cancellation action even after the parser has been removed.
This replaced an existing cleanup tail first with 0x10c and then the new peer
code, requeuing an already admitted RESET. The shared `peer_cancel/3` helper
now retains the entire existing state while cancellation is pending. It keeps
the initial terminal code, remaining commands, pending references and original
deadline. Fresh peer cancellation and critical-stream handling use the existing
path. No public interfaces or dependencies changed.

## Verification

- Expected red: `red.log`, 12 tests / 2 failures, exit 2. Both new regressions
  demonstrate cancellation replacement; existing tests pass.
- Green: `units.log`, 12 tests / 0 failures, exit 0.
- Owned-file format and strict compile: exits 0, commands in `commands.json`.
- Full minimal independent peer: 47 PASS checks, exit 0, source-bound receipt
  `minimal/run-1791781594720455934/summary.json`. Includes ordinary requests,
  311296-byte tiny-window streaming, malformed FIN/open stream errors,
  connection error isolation, request cancellation without late DATA, and
  bounded listener/runtime shutdown. All five owned children exited 0.
- Unit regression simulates an unresolved operation reference in owner state;
  it is not a claim of real unknown-operation fault injection.
- Independent Sol specification/code review and parent post-review rerun remain
  pending at this receipt. This is not an M4 completion or publication verdict.

Cumulative counters: Sol repairs **2**, unsuccessful **2**; Astra repairs **1**,
unsuccessful **0** after this validation. One bounded Astra repair remains if
new actionable review evidence requires it; counts are not reset by handoff.
All this worker's commands finished. Source/Mix lease was explicitly released
to the independent reviewer; only this new evidence directory is still owned
for the final receipt. Parent owns acceptance and subsequent milestones.
