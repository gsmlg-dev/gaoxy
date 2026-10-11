# TLS95 tooling Astra recovery1 independent review

**PASS for the bounded tooling recovery.** Both retained findings are closed; no actionable specification or code-quality findings remain. This is a tooling-only review, not a fixture or runtime verdict.

Task `m3_tls95_tooling_astra1_review`, direct independent Sol; worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch `codex/m3-gateway`, parent-supplied baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`. Specification compliance was reviewed before code quality.

## Closed findings

**TLS95-REPAIR2-01:** Collector lines24–54 now inventory roots, owned ancestors and all descendant directory/file/symlink/missing/special entries using type, mode, real path, device/inode, link target and applicable content hashes. Empty directories and root/ancestor replacement are detectable. Both Mix/Hex snapshots use owned inventories; post drift is retained and fails the gate. Symlink directories are recorded without traversing outside descendants.

**TLS95-REPAIR2-02:** Collector lines213–267 exclusively preserve the actual process wait result in a command-exit sidecar before post reads. All post metadata/log/identity reads and receipt writes are independently captured. The final receipt uses captured values; unavailable collector hash is null plus an error and cannot pass its explicit reviewed-hash comparison. A failed final write retains the earlier exit sidecar; primary-sidecar write failure still permits the final receipt and fails acceptance.

## Evidence and code quality

Fresh independent checks pass:34/34 frozen hashes; eight in-memory Python AST parses; exact before/after unified diff; current collector equals frozen recovery bytes;20/20 other recovery inputs preserved. The parent fixture-map refresh changes only the collector hash. Source changes are limited to complete inventory, safe receipt serialization/collection and required self-hash enforcement. Other tooling contracts remain unchanged and source-aligned.

The retained final regression evidence uses the same test SHA256 `209ba4328e1f8491754e9f3cdd96ba2badc9d14b13a32da072a6d4b15d7d8faa`: inherited collector RED25 cases/10 failures/9 errors/exit1; recovered collector GREEN25/0 failures/0 errors/exit0. Current collector SHA256 is `9a3339aaf839592b992a3b4596d6ab60a75fec5617a156c15c553ad1251a0890`. Reviewed assertions directly exercise retained negative cases and positive controls; tests execute only AST-extracted bookkeeping in owned temporary directories, excluding launch/peer/VM code. This reviewer verified those source/log/receipt identities and effective assertions without rerunning the unchanged suite.

Exact inputs, source locations, evidence hashes, test limits and commands are in [the JSON receipt](tls95-tooling-astra1-review.json). Historical FAILs, earlier RED and independent fixture reports remain preserved. No independent fixture conclusion is supplied by its author.

## Claim boundary and delivery

Materialization, NAR execution, compilation, Mix/VM, peer, baseline TLS RED and candidate TLS GREEN are **NOT RUN** by this review. Source/file/NAR identities establish no ABI, retained-byte formula, allocator/lifetime or M3 acceptance. Before/after inventory is not continuous monitoring; total evidence-filesystem failure is never a successful write.

Cumulative tooling Sol2/unsuccessful2 remains preserved; Astra recovery1/unsuccessful0 now passes independent changed-byte tooling review. No further recovery is requested and counters are not reset. Separate fixture Sol1/unsuccessful0 and specification Sol2/unsuccessful1 remain separate. Parent may admit the exact-hash tooling PASS gate and proceed with separately reviewed execution phases; runtime qualification still requires actual evidence.

Only these two new review reports were written. All own commands finished synchronously; no owned background process/VM/peer exists. Review-report ownership is released on delivery.
