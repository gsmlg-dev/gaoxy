# Collector2: exact observed Nix advisory classification

Task: generation-resource-consistency collector2. Status: DONE (proposal/static checks only). Direct follow-up assignment; baseline remains worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, HEAD `8160e8bb6d7f55dc836b1aed0403cc2304a539bf` from prior read-only inspection. Parent reported production edits and a running root-owned formatter; this task did not inspect or modify those edits/processes.

Owned outputs: `/tmp/gaoxy-generation-resource-consistency-collector2.py` and this note. Script1 remains byte-identical SHA256 `dd5299ab30180b3667d75a3e160f25912d0c7cf09673d33b58656ee4f52ffbe0`.

Script2 SHA256: `38afbabbbd11e88c3be4a109ec1c89e45893e3701937722bbc2da56892cd3376`.

Only `parse_log` changed. The exact root-observed line

```
warning: Git tree '/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation' is dirty
```

is recorded in `expected_environment_warning_lines`. Matching is exact after the existing ANSI/CR normalization. Paths, capitalization or extra spaces differing from that exact line are not exempt. The complete warning list remains in `all_warning_lines` and its length in `total_warning_count`; `warning_lines`, `unexpected_warning_lines`, and `warning_count` contain every other detected warning. Existing PASS logic still requires `warning_count == 0`; compiler/runtime warnings therefore still fail. No source, process, test, argv, gate, timeout, custody, or output-writing logic changed.

Validation actually executed: final AST parse; static probes for one exact advisory plus generic compiler/runtime warnings (total3, expected1, unexpected2); altered path/case/trailing-space/custom dirty warning each unexpected; ANSI-wrapped exact line expected. All PASS. `diff -u` confirms changes only within `parse_log`. No collector main, subprocess gate, runtime test, Nix, formatter, repository write or Git mutation executed. All commands finished; no child process remains from this task. Root must inspect actual command receipts; static probes do not constitute GREEN acceptance.

Counters: no repair-and-validation gate rounds introduced; cumulative inherited counters unchanged. No Astra, product decision, or external permission required.
