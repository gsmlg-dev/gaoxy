# M4 Session response scheduling correction

The coordinator continues the authorized local repair after the immutable
[Astra2 failure](../acceptance/evidence/m4/upstream-contract/run-1791833149635393377/result.json).
The cumulative direct-chain counters remain Sol 2 unsuccessful 2 and Astra 2
unsuccessful 2. No third Astra recovery is authorized. This correction is a
separately recorded coordinator repair, not a reset or a successful Astra round.

## Evidence and decision

The installed published cohort is 0.21.4. The 8 KiB supported fragment option
delivered all 64 original 16 KiB DATA calls, exactly 1,048,576 bytes with the
required hash and a single request FIN. Response polling was still receiving
DATA when the original five-second total deadline expired. The probe waited
five milliseconds after every nonterminal batch, including 218 DATA-bearing
batches (at least 1,090 ms of avoidable delay). No decoder failure or missing
required upstream API has been established. Truncated inspect output does not
prove the complete response byte count or request cleanup.

Keep the stable caller/guardian and all existing Session, ownership, teardown,
TLS, peer-window, payload, pause, queue and no-replay contracts unchanged.
In response/4, clamp its deadline to the handle's original total_deadline at
entry and retain it through recursion. Keep checks before and after polling.
After retaining the complete batch and checking the completion predicate, wait
five milliseconds only when that current batch has no headers, DATA, trailers
or done event for the target request. A control-only or other-request batch
still waits. Progress in a previous batch must not suppress an idle wait.

The existing independent 1 MiB tiny-window regression is the acceptance test.
Do not enlarge the five-second deadline, change max_read_batches: 1 or
max_frame: 8_192, weaken the response hash/FIN assertion, filter events, or
replace per-request cleanup with process exit or origin port rebind.

Record public-operation start/completion times and remaining original deadline,
plus raw poll event and DATA counts/bytes before inspect truncation. These are
diagnostic evidence only and do not change the returned result or acceptance.
All 50 required rows remain mandatory. UP1 remains on hold until full UP0,
independent source/evidence review and fresh verification pass.

Follow [the task delta](../plans/m4-session-response-scheduling.md).
