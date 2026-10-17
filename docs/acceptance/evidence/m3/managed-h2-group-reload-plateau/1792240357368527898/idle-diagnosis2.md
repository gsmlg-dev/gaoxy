# Independent idle diagnosis2

DONE; DIAGNOSTIC_ONLY_NOT_ACCEPTANCE. Direct read-only assignment in `.trees/m3-h1-resource-foundation`; supplied baseline `e4a7660baa61a792f4245f511b190a0fcfcbf920`. Only the two assigned `/tmp` reports were written.

The frozen observation reproduced the unchanged NEW-only group assertion at line4428: nativeH1→h2c, idle cycle3, exit2, 1 executed test, 1 failure, 103 excluded, source401 exact/stable, joined, not forced.

The actual G snapshot contains OLD `.55001` and fresh `.57441`, both active/inflight0, tokens0/probes0, and two baseline pins held by actual Store `#PID<0.347.0>`. The OLD pin is `.55721`; fresh pin `.49743`. The later Store snapshot has retired[], preparationnil, fresh group baseline and a distinct fresh router generation. These sequential snapshots do not establish Store.retired at the earlier G snapshot.

The source explains this phase mismatch: `generation.ex:517-526` installs the fresh baseline and queues old pins; `572-580` and `607-612` release one old pin per mailbox turn. Transport removal can independently reach the held retirement (`upstream_transports.ex:1102-1160`). The old Store baseline legitimately retains OLD active G until its separate release (`upstream_groups.ex:931-940,1041-1083`). This supports premature fixture observation, not a persistent production leak.

Both original hold starts and the diagnostic row are -576460725395ms: elapsed [0,0]ms; earliest original deadline is -576460723395ms. The original T checks before the G assertion passed by control flow: resources4/pins2/tokens0/helpers0/reserved8/failed0; actual OLD+NEW; OLD closed/charged/unconfirmed, custodians live. Capacity refusal and the complete cycle were not reached.

Recommend one explicit actual G+Store settled-phase barrier after both original held messages. Every query and poll must consume only the same earliest-original-start+2000ms budget. Require exactly fresh G1/pin1/tokens0/probes0 and actual fresh Store router/retired[]/preparationnil. Preserve all original G/Store/T assertions, capacity refusal/no-delta checks, original transaction/through_continue <2000ms clocks, and both unconditional continues. Do not add sleep, a fresh5s budget, production changes, enlarged limits, or early T release.

Frozen input hashes and detailed identities are in the JSON report. SHA256/compact receipt projections were refreshed; prior bounded raw-log/source reads are retained from the handoff. Repair efficacy and candidate3 acceptance are NOT RUN here. No tests/build/runtime/process operations. All own commands finished.

One prior oversized audit projection was truncated, disclosed, and replaced with bounded raw-log projections. Latest parent counter21: root279/orch186/groupTool32. Own added Sol repair rounds0; cumulative group fixture Sol2; Astra2/2 exhausted. No decision needed for this diagnosis.
