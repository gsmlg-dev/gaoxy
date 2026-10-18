# Diagnostic plan clarification1

This narrowly clarifies standalone-connection-diagnostic-design-plan1.md during author handoff; the prior design and evidence remain immutable.

failure_diagnostic preserves consumed original peer tuples in the existing fixture queue. event/3 previously raised failure only when received directly from the mailbox, so moving a failure into the queue could hide it from later stop/join. The fixture author is authorized to make the first queued failure or requested selector the queue match, raising the identical existing failure RuntimeError/context for a queued failure. Preserve queue order, original failure details, original deadlines and normal selector behavior; no extra query/wait/message.

The runner catches ordinary diagnostic Exception, including the existing alarm's TimeoutError, and retains only its class name before the unchanged primary accepted-connection assertion. Preserve existing KeyboardInterrupt/SystemExit behavior by leaving BaseException handling unchanged.

Only the original separately owned fixture/runner files change. No functional reuse repair, new acceptance requirement, private dependency probe or third Astra follows. Counter40 remains the entry; one fixture-author read-output incident is pending reconciliation after author handoff.
