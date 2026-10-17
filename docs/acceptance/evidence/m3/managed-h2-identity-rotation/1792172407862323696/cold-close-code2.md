# Bounded cold-close CODE2

PASS / DONE; no findings. Scope: peer-only write_closed five-replacement increment. Prior CODE1/group contracts reused by exact hashes; no unrelated system audit/runtime certification.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; baseline `8f6b884524d81d8defa7c5081230b8ab635e8107`. Cold candidate `2132111b113cf00c7464293da6b711e6fce5d0cacdb4d13029eaf1315a76fab4`; group `69cf2ae42df3a3d2a25e4281c0bede8b065eb2bd8aea91f709b86b75c7de0986`; browser `8e785b529004167a1cd13302d541c87c53554cb33e4ad175e6e8e5b85eed99e0`; SPEC2 `874285d90c1e58ac5ba625776bd55ce00b2acdcb48446b992495b64324b215f2`; peer `74fd98974e3e584d38d88883d569c70559ea8cc1cfd179ed1b1806cfd0aad04e`.

All444 mapping entries+12 scalar links+3 snapshot equalities match. Exact proposal reconstructs live peer: five matches each1,11insertions/1deletion. Only peer source changes in group/browser manifests; source key sets, argv/browser commands/rows and all other sources preserved.

write_closed is independent of eof. Actual preflush and successful base SHUT_WR precede flag=true and ACK inside the same RLock as receive_data/flush. After closure, per-connection commands and new RequestReceived fail before app-response creation. Sole completed /health/no-pending/preflush and existing response prevent app output from entering discarded buffer; closed flush drains only unsendable control output and claims no delivery. Normal flag=false behavior is preserved.

Original actual recv EOF/reset, exception classes, generic errors, finallyclose and final stop forced/live/failed/joins are byte-preserved. No BrokenPipe suppression, retry, synthetic physical event or eof mutation added. Original health/completion/Probe/accounting/GOAWAY and physical close witnesses, cold connection2, warmed reuse, selection/counts/source/custodian/final joins/caps/deadlines unchanged.

Historical group-green2 remains actual144tests/2failures/exit2 FAIL. Log has repr but no Python traceback: exact prior failing frame is unproven; the missing guard is source-evidenced and must be validated by actual rerun. Reviewer executed0 tests and no syntax/parse/import/compile/runtime/network/browser/raw trace. Root syntax2/fullthreefilegroup-green3/firstfixed2+group2browser remain required.

Own errors0; all commands finished exit0; no repo edits or old-report changes; only this /tmp pair written. Root165/orch90/tooling30/groupfailed57/runtimefailed3/fixture3/Sol3/production0/Astra2/2 unchanged; reviewer repairs0. No decisions needed. Exact commands/hash maps and limits are in JSON.
