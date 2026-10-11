# TLS95 tooling repair2 independent review

**FAIL: two retained collector gaps remain.** Tooling-only specification compliance was reviewed before code quality. No independent fixture verdict is supplied by its author.

Task `m3_tls95_tooling_repair2_review`, direct independent Sol; worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, parent-supplied reconciled baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`. No Git command ran. Only this report and its [JSON evidence](tls95-tooling-repair2-review.json) were written.

## TLS95-REPAIR2-01 / P1 — Post-run Hex inventory does not bind directories or the owned root identity

Retains `TLS95-REPAIR1-02`. Location: `.audit/m3-tls95-collector.py:22-30,145-147,212,222-223,233`.

The new pre-copy guard rejects symlinked Mix/Hex roots, unlisted directories and nonempty HEX_HOME. Post collection still calls tree(hex_home), which records only regular-file paths/hashes. It records no directories, no root real path/type, and merely resolves directory symlinks without adding them to the returned map. For an initially empty HEX_HOME, adding an unlisted empty directory or replacing the root with a symlink to an empty external directory produces the same empty map. hex_inventory_match remains true, so the new before/after guard cannot enforce the reviewed complete owned-directory identity after the command. The same file-only collector representation also omits empty tool directories.

Required change: Have the post inventory preserve and validate root/ancestor ownership and every file/directory/symlink entry, including empty directories. Require HEX_HOME itself to remain the same real owned directory and empty after execution. Apply the complete inventory to the owned Mix/tool root, retaining precise failure evidence without deleting unknown files.

## TLS95-REPAIR2-02 / P1 — An unguarded collector hash can still suppress the actual-exit receipt

Retains `TLS95-REPAIR1-03`. Location: `.audit/m3-tls95-collector.py:189-199,214-228; especially227`.

Repair2 correctly wraps protected/source/build/tool/Hex/peer post operations and record parsing with separate error capture. Final receipt construction still evaluates collector_sha256 = sha(Path(__file__)) outside collect(). The collector source is itself a frozen input. If it is unavailable after execution, protected() records the missing-input error and all other collections can finish, but this final unguarded read raises before save(name.json). The actual code from process.wait is then absent from the final receipt, reproducing the retained failure-preservation gap for a required missing-file identity case. AST inspection independently confirms this is a direct sha call in the receipt dictionary, not a guarded operation.

Required change: Capture the collector and any other required final metadata/log identity reads through the independent post collector, retaining null/error values where unavailable. Construct the final receipt from already captured data and preserve the actual process exit plus distinct post failures. Final receipt writing must not depend on rereading an input already diagnosed missing.

## Retained correct repairs

Telemetry .hex is now checked against a PASS acquisition receipt and current reviewed inventory before writes. The initial owned Mix/Hex destination and ancestors reject stale files, unlisted directories and symlinks; Hex begins empty. Cached Hex2.4.2 is independently frozen as exactly122 compiler-tool files, with no cohort BEAM reuse. Collector post operations are individually captured for protected/source/build/tool/Hex/peer inventories and malformed record parsing. Exclusive JSON/log creation and rejection of any previous run-name artifact preserve partial receipts.

The native profiler now resolves selected tools to Nix store roots, follows all registered requisite references, and compares actual NAR hashes against registered SHA256 for every returned store path, covering hidden launcher/interpreter/package files as well as ELF inputs. This collection source is statically aligned; actual selected closure, commands, timing and hashes have not executed. Source/NAR identities establish no native ABI, byte retention, allocator or lifetime proof.

The unchanged actual wrapper remains frozen at SHA256 `819be77f306c35f8546f7c8b2d665186bc6515d4372a228b402e863f1e18a7f1`: synchronized env/argv/startup, real cohort module origins/complete module sets, loaded/disk MD5 equality, same-VM application/native file identities and separate primary/post outcomes are retained. No additional code-quality findings were added after the specification review.

## Fresh verification and escalation

PASS:15/15 freeze hashes; four in-memory Python AST parses; exact122 cached compiler-tool hashes; telemetry raw archive outer/inner checksums and16 shipped hashes; .hex receipt/inventory identity;63/63 inventory input hashes. AST inspection confirms the unguarded final collector hash read. Exact inputs and preserved report hashes are in the JSON receipt. No reviewed tooling was imported or executed.

Source materialization, NAR execution, compilation, wrapper VM, baseline RED and candidate GREEN are **NOT RUN**. Fixture independent review is **OUT OF SCOPE**. Native/ABI/retained bytes/lifetime/M3 remain **NOT QUALIFIED**.

Cumulative tooling Sol repairs2, unsuccessful2 after this FAIL, Astra0. Separate specification remains Sol2/unsuccessful1/Astra0; fixture remains Sol1/unsuccessful0 at this freeze. Routing status: **ESCALATE_TO_ASTRA**, `astra_gate=SOL_REPEATED_FAILURE`. Repair1 and repair2 both failed independent review on complete inventory/final failure evidence; no third Sol repair or counter reset is attempted. Parent must validate the gate and arrange bounded collector recovery for these two gaps, preserving passing work and historical reports. No user/product decision is needed.

All own commands finished synchronously; no owned background process/VM/peer exists. Both review-report ownerships are released on delivery.
