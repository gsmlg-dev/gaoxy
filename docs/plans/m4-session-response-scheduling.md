# M4 Session response scheduling task delta

The coordinator owns the existing four upstream harness files and the exclusive
Mix/live lease. Independent reviewers own only new immutable review receipts.
This applies the [scheduling design](../designs/m4-session-response-scheduling.md)
after the Session, consumer-affinity and fragment-size amendments; all remaining
UP1/UP2/standalone/browser/consumer and publication gates remain required.

1. Preserve every earlier failed run and the Sol2/Astra2 unsuccessful counters.
   Record this as coordinator local repair 1, with no further Astra recovery.
2. Correct only response/4's avoidable progress waits and original deadline
   clamp. Preserve the complete event list, order, predicate and 50 row names.
   Add raw event/DATA byte and operation-time metadata before truncated inspect.
3. Under the serial lease, run the definitions-only compile and exact-file
   formatting check. Check Python AST and source/spec links. Freeze source,
   lock, original acceptance and candidate hashes; get independent specification
   and then code review before live execution. Static checks are not UP0 PASS.
4. Run the unchanged regression gate:

   ```sh
   nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python \
     integration/http3/upstream/run.py --gate session-contract \
     --evidence docs/acceptance/evidence/m4/upstream-contract
   ```

   Require all 17 network, 2 policy and 31 double rows, exact request/response
   bytes, original deadlines, confirmed per-request cleanup, all child exits,
   source stability and port rebind. Record FAIL and NOT RUN truthfully if it
   fails; diagnose the new evidence without resetting the earlier counters.
5. Independent review of the actual run, followed by a fresh repeat from the
   reviewed source. Only then release UP1 for production implementation.
