# Merged-main CI evidence

All ten jobs across the following push workflows passed for the exact merged
main source `14287f30b83ccec207ffc944867413043cb8f360`:

| Workflow | Run | Jobs | Outcome |
| --- | --- | --- | --- |
| Unit tests | [39554903610](https://github.com/gsmlg-dev/gaoxy/actions/runs/39554903610) | 2 | PASS |
| Static checks and build | [39554903614](https://github.com/gsmlg-dev/gaoxy/actions/runs/39554903614) | 3 | PASS |
| Foundation integration tests | [39554903599](https://github.com/gsmlg-dev/gaoxy/actions/runs/39554903599) | 5 | PASS |

Both the final run APIs and all ten checkout log receipts identify that exact
commit. This is fresh merged-main evidence, separate from the earlier
[PR evidence](../hosted-final/README.md).

Unit records `REPAIR_PASS 180 executed, 0 failures, 0 excluded, 0 skipped`
on each platform: Ubuntu Elixir 1.18.5/OTP 28.5 and macOS Intel Elixir
1.20.1/OTP 29.0.2. Foundation native HTTP records `REPAIR_PASS 207 executed,
0 failures, 0 excluded, 0 skipped`, followed by five Phoenix listener ownership
tests with zero failures. Optional QUIC records four tests with zero failures.

Each portable platform executes eight ordinary loopback tests, then one test
with seven exclusions, plus one external core consumer test. Ubuntu reports
the second invocation as `8 tests, 0 failures, 7 excluded`; macOS reports
`Result: 1 passed, 7 excluded`. Both are preserved verbatim in the receipts
and full logs. Displayed totals are not blindly summed. Both portable release
assemblies and the isolated-network job also passed.

The `*-run.json` and `*-jobs.json` files preserve complete final API responses.
Each `*-receipt.json` binds its commands, exits, final jobs, checkout identities,
test summary lines, log bytes, and hashes. Full raw run logs are preserved as
deterministic gzip streams (level 9, zero mtime). `receipt.json` collects all
three outcomes. `initial-status.json` preserves the first monitor snapshot
while Unit and Foundation were still running; `latest-status.json` records
all three terminal successes. Pending snapshots do not imply failures or passes.

`manifest.json` inventories every sibling file except itself and records each
original `.audit/mixed-h2c/main-ci/` path. Original audit files remain unchanged;
periodic polling did not create snapshot files. Monitoring used read-only
GitHub APIs and run-log downloads, without workflow retries or cancellations.
This archive establishes hosted CI results only; release publication,
downloaded artifacts, consumers, deployment, and production acceptance have
separate evidence and scope.
