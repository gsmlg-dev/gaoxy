# M4 Session observation overhead correction

The immutable [coordinator repair1 run](../acceptance/evidence/m4/upstream-contract/run-1791834217971221876/result.json)
still failed after 37 rows, leaving 13 NOT RUN. It records exactly 901,615
response DATA bytes over 753 successful polls, with 2,359 ms inside public poll
calls. A separate guardian identity RPC follows every operation, even after an
operation reaches its deadline; the final failure is missing that identity RPC.
Large printable binary inspection also remains inside the request deadline.
The complete 1 MiB response and tiny-request cleanup are still unconfirmed.

Keep every public operation, stable caller, advanced Session result, correlation,
deadline, wait rule, peer, body/hash/FIN and cleanup assertion unchanged. The
coordinator's local repair2 removes only duplicated diagnostic work:

- Add a traced variant of the existing guardian call message. At the existing
  correlated result/rejection boundary, return the unchanged public result
  together with the guardian's observed caller PID, liveness and mailbox
  high-water. The result uses the same RPC reference; no cached identity is
  substituted. Ordinary double call messages retain their existing reply shape.
- Preserve the caller-result, request-id, generation, sequence and deadline
  checks before issuing this reply. Tracing changes no scheduling or admission.
- Limit printable binary diagnostics to 64 bytes. Compute exact raw poll event
  count, DATA count/bytes and DATA SHA256 before inspection. Actual verification
  continues to use all original response bytes and events, not these previews.
- Keep bootstrap's explicit identity/adoption receipt and every normal stop,
  endpoint/task DOWN and rebind requirement. No process shutdown certifies the
  timed-out request retroactively.

The direct-chain counters remain Sol2/unsuccessful2 and Astra2/unsuccessful2.
Coordinator repair1 is unsuccessful; repair2 is separately recorded. No third
Astra round, reset, dependency patch or new API claim is selected. The installed
published cohort remains0.21.4 and upstream#105 remains severity needed/open.
Follow [the task delta](../plans/m4-session-observation-overhead.md); UP1 remains
HOLD_UP0 until complete reviewed qualification and a fresh repeat pass.
