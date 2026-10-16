# Alias-retirement core failure diagnosis

DONE — source-supported fixture lifecycle mismatch.

Original owner(gate) raw spawn has trap_exit=false. Bootstrap Process.link(owner) is installed as child runs during held Gate callback/alias retirement. Gate cancel_operation kills worker with :kill, which propagates linked :killed to owner; owner may die before forwarding cancel alias response and its parent lease is removed. Native HTTP owner already traps exits via ThousandIsland.Handler init. The fixture conflicts with its own surviving-owner/cancel :ok/parent baseline expectations.

core-green1 68 executed/1failure/exit2/joined, test471 fails at485/assert_reply694 with empty mailbox after2000ms. The saved log lacks an actual ownerDOWN observation; root runtime validation is still required.

Minimal repair: Opt-in trap_exit fixture owner for alias-retirement case only, defaultfalse elsewhere. Keep all original assertions; add actual worker monitor/DOWN:killed and live owner. Do not remove production links, globally change other fixture owners, weaken baseline/cancel assertions or add sleeps.

Constructor impact: NONE: production source and all95 role constructors/lifetimes/multiplicities/equations unchanged. Actual native owner already traps exits; worker EXIT envelope already included.

Actual root fixture repair passes the separate source review. No tests were run by this reviewer. Initial test hash guard caught the authorized root edit before report writes, then explicit updated handoff rebound the review.

Counters group32/root37/stage2 failedGREENs/Astra2/2 exhausted retained. Reviewer adds0live attempts/0repairs; no reset or Astra escalation. All own commands finished; no repository/evidence mutation. Only assigned /tmp reports written.
