# Independent peer FIN/STOP observation diagnostic

Task `m4_peer_diagnostic`, direct parent assignment to `/root/m4_spec_review`.
Worktree `.trees/m4-http3`, branch `codex/m4-http3`, HEAD `2b4a5e5`, baseline
`78de9d0`. No Connection source or dependency edits by the diagnostic worker.
Parent owns separately bounded Astra recovery1; Sol2/unsuccessful2 remains
recorded and is not reset by this fixture diagnosis.

`run-1791781331053387233/summary.json` records the source-bound diagnostic run:
**PASS, 2 real peer probes plus 1 bounded runtime-stop check**, exit0, fixture and
peer exited. Exact command: inside `nix develop`, `MIX_ENV=test`,
`ERL_FLAGS='+S 2:2'`, run `python integration/http3/run.py --gate diagnostic
--evidence docs/acceptance/evidence/m4/peer-diagnostic`. Python3.12.13,
aioquic1.2.0, Elixir1.18.5, OTP28, ERTS16.4.0.6. The runner verified all hashed
source remained unchanged; Connection SHA256 is
`975b4fb5350d23bf07e56b75a50ced1699ce622611ea304ae00b8ca64cf542a3`.
The original failing acceptance runs remain untouched.

The FIN probe retained the original 10-second BOTH-callback predicate and
recorded its failure to observe STOP: stream4 RESET callback270 (0x10e), STOP
callback absent, connection close nil, zero response DATA, elapsed10010ms.
Independent public aioquic qlog decoded **RESET270 and STOP270 on the wire**.
A sibling completed after that observation and no DATA arrived later. With the
request direction open, both callbacks270 arrived within28ms; qlog again decoded
both frames, the same connection remained open, a sibling completed, and zero
late DATA was observed. `observations.json` extracts exact values; raw public
qlog is retained in `diagnostic.log`.

The installed aioquic source provides the explanation: connection.py3116 retires
finished streams;1335 raises StreamFinishedError for later stream frames;2460
ignores those frames after decoding. STOP is logged before stream lookup in
`_handle_stop_sending_frame`2184. No private host/engine or patched dependency was
used. qlog and QuicConfiguration's logger are supported peer instrumentation.

`rfc9000.txt`, `rfc-source.txt` and `rfc9000-section3.3.txt` preserve the fetched
RFC and SHA256. Section3.3 Permitted Frame Types allows STOP in states before
RESET received, but says there is little value in Data Recvd because all data is
received. Therefore mandatory application STOP callback after FIN+RESET was an
invalid observation contract; neither an absent server wire frame nor a required
server ordering change was established.

## Separately recorded fixture contract repair

After diagnosis, stream-error FIN cases require exact RESET code, preserve any
observed STOP code equality, and still assert the connection remains open, a
sibling completes and response DATA cannot grow after reset. Five open-direction
variants require exact RESET **and** STOP codes, plus the same sibling/scope and
no-late-DATA assertions. Body-length underflow retains its necessary FIN. No peer
deadline, H3 error code, DATA equality, malformed case or meaningful directional
assertion was dropped. Timeout observations now expose reset/stop/close/body
values without changing deadlines. Public diagnostic mode is a separate probe;
it cannot substitute for the full minimal gate, which remains pending recovery.
Python compilation of fixture runner/peer passed after repair. Parent/Astra owns
fresh full minimal validation and review. All diagnostic commands finished;
no child or Mix process remains owned by this worker.
