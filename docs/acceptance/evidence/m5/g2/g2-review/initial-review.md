# M5 G2 initial independent review

SPEC PASS, then CODE NEEDS FIX: h2_peer.py:89 feeds empty H2 DATA/END_STREAM to an already closed wsproto connection after normal Close, causing LocalProtocolError. Both ordinary peer profiles reached13/15 then failed along that exact traceback. Feed only nonempty WebSocket bytes while retaining HTTP2 flow-control acknowledgment, StreamEnded handling and normal Close assertions. Production implementation has no actionable findings from the bounded static review.

Static review traced localfalse-default activation/setting8, RFC header validation, immutable CONNECT routing, owner-before200 originaldeadline validation/lifetime replacement, shared sameworker callbacks, bounded demand/consumption credits, acknowledged finite writes and normalClose/END_STREAM join. No outbounddial is introduced. Task2a remains SPEC/CODE PASS.

Observed source receipts: initial26/1 exit2; repaired26/0 exit0; altered contract selectors2executed/0 (51listed49excluded). The initial newtest expected only status200, incorrectly excluding legal Plug cache-control. Corrected require200/noH1/framing fields matches the approved contract; preserve the originalfailure and parent test-contractrepair1 counter. Initial H2/h2c peer receipts remainFAIL with13PASS and2NOTRUN each, graceful fixture shutdown0. RuntimeG2 acceptance remains pending repair/fresh checks.

All reviewer shell commands completed. No Mix/build/network commands or implementation edits by reviewer. Source hashes in initial-snapshot.json. Review repair rounds0; inherited counters unchanged. NoH3, Phoenix or browser acceptance claim and no specialist test requirements added.
