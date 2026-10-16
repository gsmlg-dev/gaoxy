# Diagnostic revision3 handoff

DONE: direct fixture-only proposal at `/tmp/gaoxy-native-worker-browser-diagnostic-host3.exs`, SHA256 `7cbfdfd222e586a26a059142911d452d8ec40748954ca184cea3f9c8f4113d4b`. Based on immutable diagnostic-host2 SHA256 `6dd5233ba91b619ada269abd7af1d1f7dc06004ecf7dbcb1cbb930743ad1781d` in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation` (baseline `58307a7084298db309a93697b9102b2cc4c87eda`).

Real H2 connection/writer IDs derive from exchange transport state and actual connection state. Successful exact receive/send/procs/monotonic traces now precede native_accounting. Snapshots include real socket/connection/deadline fields and complete Gate leases. A second snapshot logs the exact Gate map read by the original accounting assertions; raw leases are persisted before the separately timestamped public-status call. No assumed global lease count in diagnostic collection.

Fixture-only native_accounting accepts diagnostic context; its original H1/H2 assertion bodies are otherwise exact after removing the inserted snapshot lines. On native_accounting failure, saved kind/reason/stack are logged and existing bounded trace drain uses correct IDs; diagnostic logging/drain failure cannot replace the original exception, which is re-raised with :erlang.raise. No success fallback. The strict lifecycle loop and bounded-drain/join tail are byte-identical; all accounting assertions remain. No production/source95 change.

Source read/hash/full-diff and exact assertion-body preservation checks passed. No Mix/runtime/browser/formatter/tests/Git/network commands. Only assigned proposed source and this report written; all own commands finished, no background processes. Root owns copy/format/compile and actual diagnostic2. Proposal is NOT runtime validated and never acceptance.

Diagnostic1 remains FAIL/exit1, source-stable, all actor groups gone; it failed on actual Gate lease-set assertion before tracing, so extra/missing lease identity and writer-exit cause remain UNKNOWN. Counters unchanged group37/root46/stage7/Astra2of2; no repair/GREEN count added by this proposal. No decision required.
