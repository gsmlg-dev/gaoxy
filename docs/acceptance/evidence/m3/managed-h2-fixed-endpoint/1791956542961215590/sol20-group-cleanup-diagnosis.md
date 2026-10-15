# sol20-group-cleanup-diagnosis — DONE (read-only investigation)

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; branch `codex/m3-h1-resource-foundation`; baseline `31f23eb2d915ba715a1016f254b90d9805f18a1a`.

The root cause is **unknown**. Immutable full58 executed 853 tests with one newly observed cleanup regression and exit 2. The reported line625 assertion only exposes an error class returned by the fixture's protected callback. The original failing assertion and values are absent; no speculative repair is justified.

The embedding owns the listener and baseline transport pins; the test process owns preparation/group pins. The successful test body confirms the group is empty and one embedding baseline remains per owner. UpstreamGroups only monitors the instance and is not a lifecycle participant. Probe reservation is denied (`probe_bytes: 1` versus a strictly larger reservation), so group probe helpers never start. The two transport owners are lifecycle participants. Their retirement clears pins, and valid missing-pin release is idempotent. This rules out a demonstrated retained-baseline deadlock but does not establish which cleanup assertion failed.

The proposed `/tmp/gaoxy-sol20-group-cleanup-diagnosis.patch` changes only the cleanup wrapper. It prints the original exception message and stacktrace, then reraises the same exception with the captured stacktrace inside the existing protection. The callback body, assertions and deadlines are byte-for-byte retained. Successful cleanup adds no logging. Parent should review/apply it and run one diagnostic with the same scheduler, seed and max-cases:

```sh
nix develop --command env ERL_FLAGS='+S 2:2' MIX_ENV=test unbuffer mix test --warnings-as-errors --max-cases 1 --seed 33011 apps/gaoxy_proxy/test/upstream_group_transport_test.exs
```

A nonreproducing diagnostic does not clear full58. Preserve immutable failure evidence and diagnose ordering/context with the original full58 command if necessary, without retries to obtain green. This worker did not run Mix, runtime, peers, builds or tests, and did not modify the repository. JSON contains source identities, exact findings and validation limits.

Counters inherited: FixedSol19 / unsuccessfulGREEN14 before this new full failure, CollectorSol17, Astra2/2 exhausted; parent owns updated global counters. This assignment adds zero repair rounds. All own commands completed; no background process was started. Parent needs the actual inner exception before choosing a repair.
