# Installed HTTP 0.21.3 cohort verification

**PASS for installed bytes, package metadata, archive/tag identity and exact pins/lock.**
Task `upstream_contract_status_0_21_3`, direct bounded Sol verification, worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, baseline
`85c2284a035e0b4ecbf577279eee01142702b5a3`, branch `codex/m3-gateway`.

The parent completed the serialized dependency fetch before this check. This task
read the installed sources and wrote only new cache/provenance reports. It ran no
Mix, Erlang VM, network fixture, Git mutation, private API or dependency patch.
Earlier source-review receipts record the pre-install checkpoint; this receipt
supersedes their pending installed-identity status without rewriting them.

The [JSON evidence](installed-cohort-verification.json) records all actual checked
input hashes and 175 runtime tag identities. A separate
[input binding](verification-input-binding.json) binds the verifier programs,
parent preservation inventory and its immutable before-lock/manifest hashes.
All checked installed/cache/before inputs were re-read unchanged at the end.

| Check | Result |
| --- | --- |
| Seven Hex archives versus GitHub asset bytes/digests and raw inner checksums | PASS |
| Parsed archive requirements versus Hex metadata, exact coordinated 0.21.3 | 14 requirements PASS |
| Immutable source Git blobs and reconstructed Git trees | 921 blobs, 143 trees PASS |
| Installed shipped files versus archive bytes | 196 files PASS |
| Installed runtime files versus immutable tag, with no extra unshipped lib paths | 175 files PASS |
| Installed `.hex` finite ETF identity and both checksums | Seven packages PASS |
| Exact direct pins and complete expected lock tuples | Two pins, seven changed entries PASS |
| Unrelated lock entries and surrounding untouched lines | 17 entries PASS |

The before files equal the parent's hashed preservation inventory. Current proxy
manifest equals the preserved one after only its two `== 0.21.2` strings become
`== 0.21.3`; all other bytes are identical. Every complete cohort lock tuple is
reconstructed from verified metadata/checksums, including dependency flags and
repository. No lock keys were added or removed. The 17 unrelated entries and
all other lines are byte-identical to the preserved lock.

The source tag is `ceecbf2df62ca80c361597c7303f65a153f2ce3c`; reconstructed tree is
`6a44b862e8a09fb2648e48f928e37c20b1c8109a`. The
[runtime inventory](runtime-source-inventory.json) lists absolute cached paths and
sizes; installed byte equality makes it the same 175-file, 1,711,134-byte runtime
source set. [Source review](source-api-review.md) describes #98/#100 behavior and
original-completion pending semantics. Source inclusion and identity do not prove
that the requester's functional fixtures pass.

Reproduce offline from this worktree; omit `--record` from the source verifier,
and give the installed verifier a new record filename because evidence writes
are create-only:

```sh
python3 .audit/m3-transport/upstream-0.21.3/verify.py
python3 .audit/m3-transport/upstream-0.21.3/verify-installed.py --before-lock .audit/m3-transport/continuation-2026-10-11/before/mix.lock --before-manifest .audit/m3-transport/continuation-2026-10-11/before/apps/gaoxy_proxy/mix.exs --record installed-recheck.json
```

All own commands completed. Source task Sol repair rounds 0; no Astra recovery.
The parent's fixture Sol2/unsuccessful2 and TLS Sol2/unsuccessful2/Astra2 counters
are preserved separately and are not reset by this verification. Independent
review, compile/loaded identity and scoped runtime gates remain parent-owned.
Feature #97 still blocks the complete numerical envelope and managed production
activation; this source/installation PASS does not release that gate.
