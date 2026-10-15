# Scoped command collector proposal

Task: generation-resource-consistency collector. Status: DONE (proposal/static validation only).
Assignment: direct; repository runtime/build/formatter/evidence/Git remain exclusively root-owned.
R: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Inspected baseline: `8160e8bb6d7f55dc836b1aed0403cc2304a539bf`, branch `codex/m3-h1-resource-foundation`.
Observed pre-existing changes: only new slice evidence/design/plan/acceptance paths untracked. No tracked diff modified by this task.

Owned output: `/tmp/gaoxy-generation-resource-consistency-collector1.py` and this note only. No repository writes, command-gate runs, commits, processes left running, or dependency changes.

## Invocation by root

`python3 /tmp/gaoxy-generation-resource-consistency-collector1.py <unique-receipt-stem> <gate> [seed]`

Gates: `consistency`, `router`, `core`, `compat`, `format`, `compile`, `toolchain`; seed defaults to 1. Files are exactly those in plan Task 4. `format` checks precisely Router, Generation and the new test; it does not write formatted files. Tests use `--warnings-as-errors --max-cases 1 --seed N`. Every command uses `nix develop --command env 'ERL_FLAGS=+S 2:2' MIX_ENV=test unbuffer`, with `mix` except `elixir --version` for toolchain. Actual argv is recorded without shell interpretation. One gate subprocess is launched per collector invocation; Git identity is read directly from worktree/common Git files.

Outputs: new `<stem>.log` (merged raw stdout/stderr) and `<stem>.json` under the assigned E2 directory. Both names are claimed exclusively; existing outputs are never overwritten. If JSON was already present after the log name was claimed, the newly claimed empty log remains preserved and the command is not started. Choose a fresh stem.

Guards: kickoff manifest paths plus every `.ex` under apps/gaoxy/lib and apps/gaoxy_http/lib, both additional app test helpers, and scoped proxy HTTP/Session/GroupEndpoint/UpstreamGroups/UpstreamTransports sources. Inspection found 86 paths; only the new test was absent. Each guard records its full path, SHA256 and size. Before/after enumeration detects new/deleted core or HTTP source files. The new test may be absent only when actually absent and is hashed once present. An absent different guard is a collector error. Source stability additionally binds HEAD/branch, kickoff bytes and actual collector bytes. Mutable evidence output is not included in guards.

The 600-second timeout covers the launched command. Timeout/interruption sends TERM to its own new process group, waits up to 5 seconds, then sends KILL if still present and waits/reaps. Direct child join and process-group absence are separate facts; neither is invented from a requested signal. Normal group exit gets a 1-second settle allowance. A residual group that requires cleanup after direct exit forces FAIL, even if cleanup succeeds. The receipt records actual return code (including negative signal values), monotonic command and collector durations, timeout/interruption state, shutdown actions and join facts. SIGTERM/SIGHUP are caught for cleanup; repeated interruption or SIGKILL of the collector cannot promise a receipt.

Full raw log is retained and hashed; the parser reads the entire log, strips ANSI, counts every ExUnit summary across umbrella applications, records individual summary lines, totals tests/doctests/properties/failures/skipped/excluded, warnings and exclusion declarations. Counts are invocation totals, not distinct tests. Test PASS requires exit 0, joined process/group, stable source, nonzero executed invocations, no failure/skip/exclusion/warning, no timeout/interruption/collector error. Non-test gates explicitly mark `tests_applicable=false`, and require the same execution/stability/warning conditions with no test-count requirement. Intended RED remains FAIL for root interpretation against actual assertions.

## Validation actually performed

- Python AST parse: PASS, including final edited source.
- Imported in-memory with a non-main name, without executing subprocess main: PASS.
- Deterministic parser probes: two ANSI/umbrella summaries totaling tests11/doctests2/failures1/skipped2/excluded3 and executed8; warning detection; zero-test log; empty and nonempty exclusion declarations; zero-warning line: PASS.
- All seven argv prefix checks: PASS.
- Git reader: resolved exact baseline/branch above.
- Read-only guard enumeration: 86 paths, new test correctly absent.
- No actual command collector invocation/runtime gate has been run. Process timeout/TERM/KILL behavior is implemented but NOT runtime validated; root should inspect receipts on first use. These static checks are not implementation/test acceptance evidence.

Sol repair counters: no failed gate or repair round in this proposal task; inherited group24/27 and Astra2/2 remain unchanged. No Astra requested. Decisions needed: none.
