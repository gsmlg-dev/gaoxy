# Proposed candidate1 runtime DATA audit

Status: **DONE, proposal only**. The proposed Python file has not been executed or syntax checked. Runtime, tests, builds, browser, Git/inventory operations and repository/evidence writes were not performed by this agent. This is neither SPEC/CODE acceptance nor runtime acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; supplied baseline `e4a7660baa61a792f4245f511b190a0fcfcbf920`.

Frozen candidate1: `E6/source-candidate1.json`, SHA256 `3135c166ed5946c23be1f340b6d130ad7e00740f857f7d4e12cd19a0da0baca1`. Frozen test SHA256 `923e1661767ed9bb22932438e564c805671c53161ce9dcb240f1d9d99ea09d3e`; new source lines 3178–4954. The candidate inventory has 409 entries; its distinct actual-command source map has 402. The proposal compares the latter map exactly to the collector's stable before/after maps.

Owned outputs:

- `/tmp/gaoxy-group-reload-runtime-audit1.py.txt`
- `/tmp/gaoxy-group-reload-runtime-audit1.json`
- `/tmp/gaoxy-group-reload-runtime-audit1.md`

The script reads only three explicitly supplied files and prints JSON to stdout. It invokes no subprocess and performs no runtime access, source inventory, writes or Elixir evaluation. Proposed CLI, **not executed**:

```sh
python3 -B /tmp/gaoxy-group-reload-runtime-audit1.py.txt \
  --candidate E6/source-candidate1.json \
  --receipt E6/group-reload-first-scoped1.json \
  --log E6/group-reload-first-scoped1.log
```

Here `E6` denotes `docs/acceptance/evidence/m3/managed-h2-group-reload-plateau/1792240357368527898`. Resolve paths explicitly before any parent-owned invocation. These are parsing bounds, not product limits: candidate/receipt 8 MiB each, log 64 MiB, line 2 MiB, exactly 200 reload events. Duplicate JSON keys and nonfinite JSON constants fail closed.

The command checks bind the pinned candidate, exact command argv, source map, source hash, collector hash, environment, cwd and log digest. They require nonzero clean ExUnit counts, actual nonforced parent/descendant joins and empty remaining process sets. Python/browser/static counts remain separate. Raw adopted-child wait statuses are preserved and decoded; a genuine signal-derived exit such as -10 is not changed into exit 0 or rejected merely for being signal-derived.

The proposed event audit requires all eight upstream/downstream/profile contexts, each containing contract, setup, 22 cycles and finished in order. It checks changing generation/resource/group identity lineage; original HEAD/GET completion identities; exact peer targets, connections, streams and lane selection; source-size classes; CAS lineage; original retirement resources, creators, capabilities, receipt IDs and physical closes; paired capacity holds; rollback before/after equality; and all six peer joins per context. Opaque IDs are scoped per context and are not globally deduplicated.

All ten complete plateau fields from cycles 3–22 must equal that context's actual cycle-2 vector exactly. Numeric byte sums are recomputed from emitted charges; actual ETF serialization cannot be independently recreated from only printed byte counts. Full-record/config/control bounds and public totals are cross-checked without normalizing changing identities into the plateau. Active rollback keeps three real transport/group tokens; idle rollback keeps zero. Charges and original token/completion/selected-resource links are checked in either profile. Native reservation is an integer byte count.

Expected aggregates are 184 generations, 368 transports/HEADs/seed GETs/retirement receipts/physical closes/accepts, 176 replacement CAS operations, 264 held GETs, 632 total GETs, 1,000 requests, 184 group removals, 48 peer joins and 16 paired retirement holds. These are proposed expected counts, not observed runtime results.

The frozen schema cannot produce full DATA PASS. Source lines 3285–3297 omit final-zero ledgers even though `reload_zero/2` at 4454–4482 asserts them. Successful assertions and plateau zeros cannot replace missing final transport/group/service/gate observations. After all available emitted-data checks pass, the proposal returns `EVIDENCE_GAP` / exit 2. Inconsistent, missing, malformed or failed evidence returns `FAIL` / exit 1. Exit 0 remains unreachable for candidate1.

A second confidence limit concerns typed-event provenance: original IDs/bytes and peer frames are emitted, while normal waits, original completion awaits and processed cancellation are partly scalar test attestations. The proposal reports this separately and does not manufacture raw event envelopes. It also does not claim to validate every untouched inventory field, recompute ETF bytes from inspect strings, prove TLS cryptography from public metadata, or prove absence of un-emitted events. Bounded inspect parsing extracts only existing ref/PID/string scalar fields; it is not a general Elixir parser.

Source map: schedule/setup/final event 3178–3297; topology/classes 3301–3418; requests/cycles 3495–3700; retirement 3837–3935; rollback 3936–4048; capacity 4084–4197; vector 4218–4397; service/gate 4398–4453; discarded final zeros 4454–4482; joins/totals 4484–4594; changing inventory 4679–4745; health/GET receipts 4746–4804; snapshots 4807–4904; public peers/identity shells 4905–4950. Native reservation comes from 1698–1740; original selected/token links from 1825–1902.

Root has reported that immutable SOURCE SPEC1 is archived and the source is now being repaired for candidate2. This candidate1 proposal intentionally pins its old schema/hash and must reject the replacement candidate. A dependent candidate2 proposal requires the new freeze and explicit adaptation; the current file must not be represented as validating repaired source.

All own commands have completed. Two bounded source lookups exited 2 because guessed Transports paths did not exist; they made no changes, and the useful test-source matches were read. No runtime or infrastructure failure occurred. No repair-and-validation round was performed. Cumulative counters remain root255/orch165/tool93/group11 and Astra2/2, unchanged. Root remains sole operator/writer for repository, evidence and runtime.
