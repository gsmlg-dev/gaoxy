# ARB-CHURN — installed and qualified

DONE for assigned integration and focused validation. V15's finite ordinary
same-instance connection churn now has passing scoped runtime evidence. This
is not whole-goal/global-suite/package/release acceptance.

Direct Sol continuation, cumulative Sol repair rounds1/Astra0. Repository
`/home/gao/Workspace/gsmlg-opt/gaoxy`, existing `main`, baseline
`bc8a5ef5199293ada3b432c2e2741070d3b2d115` plus preserved accepted integration.
No production, dependency, lockfile, other test, canonical manifest, inventory or
Git mutation was made by this worker. Parent's already-updated manifest/inventory
was preserved. All source writes finished before final command fingerprints.
All commands and test processes are terminal; no background task remains.
Source/build ownership is released to parent at handoff.

## Task delta

- New `apps/gaoxy_http3/test/resource_budget_churn_network_test.exs`:3 protocol
  cases, three sequential fresh connections each, same unchanged instance,
  service generation/address/listener port, max_connections1 and no explicit
  max_bytes. Reuses established Python clients and original venv entrypoint.
- Existing `apps/gaoxy_http3/test/connection_test.exs`: **only** added
  `@moduletag :unit`. Exact annotation-only comparison against the pre-task
  snapshot passes; existing behavior/assertions are unchanged. Other12 frozen
  H3 task paths remain byte-identical to final review.
- Owned formatting applied to these two paths only. `annotation-only.diff` and
  `draft-to-installed.diff` retain the attributable changes; current snapshots
  and source fingerprints accompany the receipt.

Every churn round requires live positive request usage and exact public
connection/request/protocol stream memberships, successful independent HTTP200
with exact path payload, completion while the connection remains open, clean
client close/exit, then public zero usage/connections/requests/H2+H3 streams/
leases/pending-process credits and zero active/retained/cleanup_pending with
cleanup_failed nil before the next round. Every round checks the same Service
generation/address and uses a fresh client process/transport and endpoint worker.
All nine rounds completed in the passing focused run. No private native engine
PID or production workaround is used.

## Initial failure and one targeted repair

`churn-focused-initial.json/log`:16 tests,1 failure, exit2, source stable. The
new draft over-specified post-response H1 idle usage as positive. Actual public
snapshot had connection1/request0/streams0/lease1 and usage0. Existing
`Gaoxy.HTTP.Connection.complete` passes `byte_size(exchange.buffer)` to
`idle_accounting`, so an empty idle buffer correctly owns0 bytes while retaining
connection quota. This was a fixture-contract error, not a product defect.

Repair1 permits **nonnegative numeric idle bytes for H1 only**; H2/H3 idle
positivity, live-request positive bytes, exact terminal zero/cleanup and all
same-listener re-admission assertions remain. No payload/deadline was changed.
The initial failure is preserved. The repair-and-validation round passed.

## Final verification on identical stable source

All final receipts record the same681 full input hashes, match current source,
report no source changes and commands terminal. Raw log hashes were rechecked.

| Receipt in this directory | Actual result |
| --- | --- |
| static-final.json | Embedded Python AST/compile without execution PASS;3 explicit tests; tag-only existing-file delta PASS |
| churn-final-inventory.json | PASS unit390/component321/protocol157 =868 scheduled cases,120 active files/143 retained |
| churn-final-strict-compile.json | `mix compile --force --warnings-as-errors`, exit0 |
| churn-final-owned-format.json | Check-formatted on only two owned paths, exit0 |
| churn-focused-repair1.json | **16 tests,0 failures**, exit0, no skips/exclusions |

Focused command actually executed:

```sh
python3 scripts/check-tests.py apps/gaoxy_http3/test/connection_test.exs apps/gaoxy_http3/test/resource_budget_churn_network_test.exs --seed 0 --max-cases 1
```

Expected and actual cases:13 controlled ConnectionTest +3 protocol churn =16.
Raw focused log SHA256:
`887aee480b86ffe470a7f55c6b498d8f81958f308c5f0f1ebf7153b8bc984dce`.

Environment: Linux, Elixir1.18.5, MIX_ENV=test, scheduler cap+S2:2, established
`.audit/h2peer/bin/python` venv retained without symlink resolution. No unsupported
platform, pressure/soak, browser or product deployment evidence is inferred.

Remaining work: parent independent review/fresh integrated canonical gates,
Phoenix/package/source-built qualification and authorized delivery. No blocker,
new permission or design decision remains for this assigned scope. Do not sum
this16-case run with overlapping historical H3 runs into a global acceptance
count. All task writes stop at handoff.
