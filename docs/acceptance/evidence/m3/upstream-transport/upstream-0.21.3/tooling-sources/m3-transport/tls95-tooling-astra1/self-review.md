# TLS95 collector Astra recovery1

DONE for bounded implementation and local bookkeeping checks; independent Sol review is PENDING.

Task `m3_tls95_tooling_astra_recovery1`; mode implementation; gate SOL_REPEATED_FAILURE verified from two unsuccessful Sol repair reviews. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, baseline `b2ac78b518f459ec2c95b7823226640413f2ca95` verified through Git metadata files without Git commands. Parent confirmed exclusive collector ownership and no runtime user.

The inherited file-only tree omitted empty directories/root replacements. `tree()` now records root, entries and owned ancestors with type, real path, device/inode/mode; symlinks retain link targets and file hashes where applicable. Empty directories, root replacement, ancestor symlinks and special entries change the inventory. No stale artifact is removed. Mix/Hex snapshots are compared and failure inventories retained.

The inherited unguarded post reads and writes could prevent final receipt creation after process.wait. An exclusive command-exit sidecar now preserves its actual code first. Post file reads, source sidecar writes, metadata collection, final write and stdout serialization are individually captured. The final receipt is built from captured data. A missing collector records null plus error. Its post hash must also equal the reviewed hash because the collector was absent from protected() maps.

Source SHA256 `9a3339aaf839592b992a3b4596d6ab60a75fec5617a156c15c553ad1251a0890`. Exact inherited bytes, patched bytes and unified diff are retained as `collector-before.py`, `collector-after.py`, and `collector.diff`. Only the collector and new files in this evidence directory were written. All other20 frozen source/report files remain unchanged. Parent native-profile and other Sol H1 work was untouched.

Verification:

- EXPECTED_RED: `python3 -B .audit/m3-transport/tls95-tooling-astra1/regression.py .audit/m3-transport/tls95-tooling-astra1/collector-before.py` —25 cases,10 failures,9 errors, exit1; `red-final.log/json`. Earlier22-case RED also preserved.
- PASS: `python3 -B .audit/m3-transport/tls95-tooling-astra1/regression.py .audit/m3-tls95-collector.py` —25 cases,0 failures/errors, exit0; `green.log/json`. Same test-source hash for final RED/GREEN.
- PASS: in-memory AST parsing of all7 frozen Python sources and preservation20/20, with current collector hash bound to GREEN.
- NOT RUN: materialization, Mix/VM, peer, network, native/runtime RED/GREEN. AST extraction exercised only bookkeeping using self-owned tempfile fixtures; it never imported/executed collector startup code.

Post-failure cases cover missing/changed collector, protected drift, missing log, malformed JSON followed by valid JSON, clock error, sidecar/final write failures, existing immutable sidecar, successful zero/nonzero exits and timeout signal exit. Inventory cases cover stable empty state, Hex/Mix empty-directory additions, empty/dangling symlinks, real/symlink root replacement, ancestor replacement, special files, file content/type changes and preserved drift evidence.

Counters: received Sol2/unsuccessful2; Astra prior0, cumulative1, unsuccessful0 pending independent review. No second recovery started. The exhausted Sol repair budget remains exhausted; independent Sol review is the next gate. Any later repair follows the existing cumulative recovery budget and parent routing.

All commands completed synchronously; no owned background process/VM/peer remains. Collector ownership is released on delivery. Parent must independently review changed bytes before admitting tooling PASS or starting runtime. No product decision is missing. Snapshot checks do not establish continuous filesystem monitoring; a rejected final write retains the earlier primary sidecar, and total evidence-filesystem failure cannot be represented as a successful write.
