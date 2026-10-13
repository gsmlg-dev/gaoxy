# M4 native H2 receive window before SETTINGS acknowledgment

The complete UP2 diagnostic execution on HTTP Fetch 0.21.4 fails at
`h2-tiny_window_1mib` with a real `RST_STREAM FLOW_CONTROL_ERROR (3)`. The peer
accepted 16,383 bytes of a 16,384-byte upload chunk, then reports stream credit
-49,151. The unchanged five-second deadline and exact body/FIN assertions remain
required. This is Gaoxy's native downstream H2 window transition; it is not a
missing HTTP Fetch API. Preserve eleven unsuccessful live executions, four
failed production repairs and the repair5 harness failure. UP0's two Sol/two
Astra recovery rounds remain exhausted.

Gaoxy advertises a configured 16,384-byte initial stream window but currently
enforces it at admission, before the peer receives/acknowledges that SETTINGS.
RFC 9113 section 6.9.2 permits the default 65,535-byte window until that transition.
Use 65,535 for streams admitted before the first acknowledgment of our SETTINGS.
On that acknowledgment add `configured_receive_window - 65_535` to every existing
stream's remaining receive credit, exactly once. Preserve negative credit; do not
clamp it or return extra credit. Admit later streams with the configured window.
Duplicate acknowledgments retain the existing acceptance policy and cannot
repeat the delta. Peer SETTINGS still adjust the independent send window.

A zero-length DATA frame, including END_STREAM, consumes no flow-control credit
and remains legal when the stream credit is negative. Positive DATA or padding
above the remaining credit retains the exact flow-control error. Connection
credit, max-body validation, concurrency, deadlines and existing WINDOW_UPDATE
accounting remain unchanged. The existing stream reservation includes 65,536
bytes of pending input, covering the default initial credit; no budget increase,
new process, dependency modification or retry is needed.

Raw-frame native h2c regressions hold the real endpoint before it returns body
credit. PING acknowledgments establish wire ordering. Verify legal pre-ACK flight,
the first ACK's negative-credit transition and zero-byte FIN, duplicate ACK
idempotence, positive oversends on existing and new post-ACK streams, exact bytes,
sibling success and bounded cleanup/rebind. Actual RED precedes production edits.
The existing independent H2/TLS 1 MiB tiny-window row remains the full protocol
acceptance. The separate raw-delivery buffer candidate has no confirmed failure
evidence and is outside this repair.
