# M4 Session abort/stop task delta

Root owns probe, runner/README counters and docs. Independent reviewers own new
immutable receipts only. Serialize all Mix/live work and freeze executable sources.

1. Preserve repair4 FAIL47 PASS / 1 attempted FAIL / 2 NOT RUN and its confirmed
   local teardown. Retain four unsuccessful coordinator repairs and Sol2/Astra2.
2. Idle cleanup commands abort first, stopping on result or the existing <=100 ms
   fallback capped by unchanged grace. Outstanding/absent/lost caller or unresolved
   bootstrap stops immediately, including caller loss during an abort. Preserve
   no-replay and advanced state.
3. Within the existing caller_down_before_stop_result row, prove fast abort
   completion triggers stop (not the fallback), blocked abort exercises fallback,
   all tasks terminate and the
   original absolute cleanup deadline remains unchanged. Keep its old assertions.
4. Definitions-only compile, exact-file format and Python AST; freeze hashes and
   obtain independent SPEC then CODE review before the unchanged full 50-row gate.
5. Review actual evidence and run a fresh repeat before UP1 release. Never claim
   local stop/DOWN/rebind alone as peer cancellation or Service completion. No new
   upstream issue, third Astra, deadline extension or weakened assertion selected.
