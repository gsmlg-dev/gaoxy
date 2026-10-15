# Active initial-health GOAWAY: code review and exact proposal1

PASS SOURCE ONLY for the proposed two-file patch; runtime NOT_RUN. Browser5 remains FAIL.

Task `/root/browser_contract_spec/active-goaway-code1`, direct read-only assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`; candidate5 `fcd3fdd1b358722f8e6714363b6a0e9f44d8c3390fdfffd6074e8e333928820d`. All198 current hashes match candidate5. Root and other agents retain repository/runtime ownership; only the three assigned /tmp files were written.

Patch `/tmp/gaoxy-group-browser-active-goaway1.patch` SHA `3fbd8753eb44786c0e09b05c032c265cf6935ba81b3c02199219d16a3f5b8eff`.

| File | Base SHA256 | Proposed SHA256 |
|---|---|---|
| apps/gaoxy_proxy/test/support/managed_h2_group_browser_peer.py | 0b73127aa1f3cf3d7a9257526db158c40b3ec76913089c028397175e5bafd259 | 32fedd373c42b37e37f1c87fe1986df05dd12aef46e8e96f48dc583d4e639772 |
| integration/http_fetch_contract/managed_h2_group_browser.py | 5c6544a5b3f70329f083ad2fb48b522b81fe7a990135136a12358dd436ef6dfa | 478236b7876ffa47bd945be92d2475b7f9a2a3e07f49b83cc6a53b55efa4b81a |

Browser5 first negative starts after host confirms initial health completion. The immutable peer log shows realHEAD, upload_end, lateGOAWAYcommand and eventualEOF; consumer20s await expires first. Current runtime GOAWAY handling starts default30000ms draining; successful active stream release stops a draining owner when its stream map becomes0. An already released health stream supplies no later release transition. This traces the mismatch to fixture ordering. The eventualEOF log alone is not precise timing/cause evidence.

The proposal adds GroupBrowserPeer.automatic: only negative, unrotated exact /health HEAD calls super().command with realGOAWAY connection/stream/last_stream/code0 before super().automatic responds. It removes the orchestrator late send and keeps waiting for the actual inherited command event, with one additional exact health connection/stream/last_stream/code requirement.

Peer.serve calls automatic while holding threading.RLock; inherited command and emit reenter on the same worker thread. The existing command sends the actual frame through the live TLS socket: type7, flags0, stream0,8byte last-stream/error-code payload. Its existing rawsend leaves hyper-h2 state able to respond on the accepted stream. No duplicated framing, fakeEOF, new socket close/shutdown, synthetic success, thread, sleep, deadline or dependency change. It sends GOAWAY before response serialization, so the client still has the accepted stream when it processes GOAWAY.

AST comparison preserves all41 original canonical require calls, all original event calls and their arguments, and adds exactly1 strict GOAWAY identity requirement. The original same-connection physicalEOF20s deadline is unchanged. All rotation/realhandshake/browser502/body/replay/peerjoin/Service/fullreservation/G/T evidence/cleanup/threecase/threebrowserjoin requirements remain. The positive fixture path is unaffected. Both proposed files compile in memory and exact reverse replacements recover base bytes. No imports or runtime/test execution occurred.

Fresh full canonical3 runtime is still required; later failures remain possible. Rebind both changed canonical/peer hashes in the next reviewed source manifest and tooling; never reuse an old canonical hash or describe earlier25 commands as new-source executions. This is an initial-health activeGOAWAY scenario, not proof of immediate idleGOAWAY close or a production runtime fix. Historical failures/cleanup labels remain.

Parent-current24 failedGREEN/26 root events; reviewer0 repair-and-validation rounds, Astra2/2 exhausted. All commands finished. No decisions needed.
