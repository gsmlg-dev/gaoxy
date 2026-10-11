# Installed HTTP 0.21.2 cohort verification

Task `m3_0_21_2_install_review`, direct independent Sol verification.
Date: 2026-10-11 Asia/Shanghai. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `81b01bd3334fe4c90a739e1eebdee8bd29bf94f8`.

**PASS for installed source, archive, metadata, direct-pin and lock identity,
and preserved old artifacts.** No actionable identity finding remains.
This receipt permits the parent to begin its separately owned runtime gates.
Runtime compatibility, fresh compiled/loaded identity, TLS lifecycle, byte
accounting, complete P0–P6 and production acceptance remain unqualified here;
managed activation remains disabled.

Only these two new verification reports are owned by this task. Existing
parent and peer changes are preserved. No Mix, Erlang VM, formatter, network,
dependency mutation, process inspection, Git mutation, subagent, private API,
dependency patch or production activation was used.

## Independently recomputed installed identity

The [JSON receipt](installed-cohort-verification.json) contains actual archive
and member hashes,205 installed input hashes,175 runtime/tag blob identities,
23 review-input hashes, exact before/after lock entries, preservation hashes,
and the complete independently authored standard-library Python verifier.

| Package | Installed shipped files | Runtime `lib/` files | Identity |
| --- | --- | --- | --- |
| `elixir_quic` | 26 | 23 | PASS |
| `elixir_quic_http3` | 16 | 13 | PASS |
| `ex_ssl` | 63 | 58 | PASS |
| `http_core` | 34 | 32 | PASS |
| `http_fetch` | 21 | 17 | PASS |
| `http_runtime` | 24 | 22 | PASS |
| `http_web_socket` | 12 | 10 | PASS |
| **Total** | **196** | **175** | **PASS** |

For all196 shipped paths, actual installed bytes equal the actual cached
`contents.tar.gz` member and both separate release/source receipts.
The175 runtime files also equal their immutable tag source bytes and Git blob
identities. Installed `lib/` path sets contain no additional unshipped files.
Receipt claims are not a substitute for reading archive and installed bytes.

For each of seven packages, verification independently:

1. Hashes raw `VERSION || metadata.config || contents.tar.gz`, checking equality
   with archive `CHECKSUM`, lock inner checksum and installed `.hex` inner
   checksum. All archives use format3.
2. Hashes the complete cached Hex `.tar`, checking equality with cached GitHub
   archive bytes and published asset digest, cached Hex metadata checksum,
   lock outer checksum, `.hex` outer checksum and separate source receipt.
3. Parses finite archive metadata without code evaluation, checking package
   name, app, version0.21.2, Mix manager and all requirements. Internal exact
   requirements are `== 0.21.2`; telemetry remains `~> 1.0`. Constructs and
   compares each entire expected lock tuple, including flags and repository.
4. Decodes actual binary `.hex` ETF without a VM. The finite header
   `{hex,2,0}`, name, version, `hexpm`, Mix manager and both checksum fields
   must match exactly; unsupported term tags and trailing bytes fail.

The cached immutable source archive SHA-256 is
`8db7e6d7bc90c88663719e86ac5b04b7e09a149fc6ea60acd5fb3a78235ef571`.
All919 source blobs were hashed with the Git blob prefix, including three
symlink target byte strings. All143 Git trees, including the root, were
reconstructed using modes, names, ordering and binary object IDs. The root is
`664a2a0de2bd4820017599b2d25f62bc7dcf63b0`, agreeing with cached
tag/ref/commit `f677ca49519a007a7a551a5a515127c0f29d8ae6`.
This offline check binds cached bytes to the immutable tree; it performs no
fresh network lookup and makes no commit-signature authentication claim.

Both existing direct pins, Fetch and WebSocket, are exactly `== 0.21.2`.
The proxy manifest equals baseline bytes after replacing only its two existing
`== 0.21.1` strings. Current manifest SHA-256:
`1f9f10de8b06560ba101d07109fc78cd819eec0741a8a39e17ad044d5d12c867`.

The root lock has24 entries. Comparison with
`git show 81b01bd3334fe4c90a739e1eebdee8bd29bf94f8:mix.lock`
finds exactly seven cohort entries changed, no additions or removals.
All17 unrelated entries and their complete lines are byte-identical; every
other lock line is unchanged. Current lock SHA-256:
`ad115e772d535f560dfc083003524e42aae88a879eca8602516e54f5d14026c0`.
Baseline hashes and full exact tuples are recorded in JSON.

## Preservation and fetch receipt

Fresh hashes validate all429 copied old source inputs against
[pre-upgrade preservation](pre-upgrade-preservation.json). Its entire map also
equals both frozen source maps of the historical0.21.1 final receipt.
All34 copied disk BEAMs match receipt hashes and structurally valid BEAM
container headers and lengths. These are preservation copies, not fresh
loaded-code identity or source reproduction.

The collector's separate `installed-0.21.1/` copy contains196 shipped old files.
Each copied byte sequence matches its actual0.21.1 cached archive member,
the collector freeze map and the independently authored source/API review map.
Historical reports and package sources were preserved.

The parent's [fetch receipt](deps-get.json) records exit0 without timeout;
its [raw log](deps-get.log) independently hashes to
`6cfb13ef972f6d7eab43ac0bd164e44b158895e8cce523c94d2ae1df2d93fc68`.
This reviewer did not rerun dependency resolution.

## Finite scope and reproducible verification

The separate [source/API review](source-api-review.md) establishes shipped
0.21.2 TLS95 source containment. This installation check validates installed
candidate identity; it makes no runtime, lifecycle or byte claim.
The [qualification specification](qualification-spec-review.md) is a separate
staged plan review; its installed0.21.1 observations remain historical.

The frozen empty pure model and22 pending-red tests, peer TLS fixture design,
and earlier accounting/frontier plans belong to later stages and are excluded
from this cohort delivery. Next checks remain parent-owned: fresh compilation
and load identity, scoped compatibility, existing full39 functional checks,
and the separately reviewed TLS lifecycle fixture. Complete P0–P6,
arbitrary-history resource bounds and TLS byte envelopes are unqualified.

The independent Python verifier ran with exit0 and the nonzero counts above.
It uses only local reads, standard-library hashing/archive/finite metadata
decoding, and read-only Git identity/baseline commands. All installed, archive,
preserved and review input hashes were re-read at the end and remained unchanged.
Its exact source and hash are embedded in JSON. Reproduce from this worktree:

```sh
python3 - <<'PY'
import hashlib, json
from pathlib import Path
p = Path("docs/acceptance/evidence/m3/upstream-transport/upstream-0.21.2/installed-cohort-verification.json")
receipt = json.loads(p.read_text())
source = receipt["verification_program"]
assert hashlib.sha256(source.encode()).hexdigest() == receipt["verification_program_sha256"]
namespace = {}
exec(compile(source, "<independent-installed-cohort-verifier>", "exec"), namespace)
fresh = namespace["result"]
for key in ("validation", "packages", "archive_sha256", "installed_input_sha256",
            "runtime_tag_identity", "changed_lock_entries",
            "unrelated_lock_entries_unchanged", "preserved_source_sha256",
            "preserved_beams", "preserved_old_installed_sha256",
            "review_inputs_sha256"):
    assert fresh[key] == receipt[key], key
print(fresh["status"], fresh["validation"])
PY
```

Task status **DONE — installed/preservation identity PASS**. Sol review repair
rounds0, unsuccessful0; received Astra0, recovery rounds0; `astra_gate: none`.
All own commands finished synchronously; no background jobs, VMs or peers
started. A tool-wrapper quoting error occurred before execution or file writes;
the corrected receipt generation and reproducible verifier passed. This did
not cause an implementation repair or change any inspected input.
Ownership of these two reports is released to the parent on handoff.
No new product decision is needed.
