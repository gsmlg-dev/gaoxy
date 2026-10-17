# Candidate2 runtime DATA audit proposal

**DONE, proposal only.** No syntax check or script execution was performed. No runtime, test, build, browser, Git/inventory or repository/evidence mutation was performed. All own commands completed.

Frozen worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`; supplied baseline `e4a7660baa61a792f4245f511b190a0fcfcbf920`. Parent supplied candidate2 SHA256 `75e790fdb8fee8b17279a807cb8a826a2ad1596b0f1b7fc9250287347b85a19f` and test SHA256 `144ff05c2de10f600c9776565711f1072e08e8487b914c5c42250118230ff535` (181646 bytes, 4966 lines). Bounded source reads confirmed candidate2 metadata and emitted schema; no repository hash/inventory command was run.

Owned files:

- `/tmp/gaoxy-group-reload-runtime-audit2.py.txt`
- `/tmp/gaoxy-group-reload-runtime-audit2.json`
- `/tmp/gaoxy-group-reload-runtime-audit2.md`

The script remains read-only: three explicit candidate/receipt/log file inputs, stdout JSON output, Python standard library, no subprocess/runtime access, inventory or writes. Proposed CLI, **not executed**:

```sh
python3 -B /tmp/gaoxy-group-reload-runtime-audit2.py.txt \
  --candidate E6/source-candidate2.json \
  --receipt E6/group-reload-first-scoped1.json \
  --log E6/group-reload-first-scoped1.log
```

`E6` denotes `docs/acceptance/evidence/m3/managed-h2-group-reload-plateau/1792240357368527898`; parent must supply the explicit resolved paths. Parsing bounds remain candidate/receipt 8 MiB each, log 64 MiB and line 2 MiB. Duplicate JSON keys and nonfinite constants fail closed. Exit 0 means emitted DATA checks passed; exit 1 means malformed, missing, failed or inconsistent data. These are proposed outcomes, not observed results.

Candidate2 resolves the missing final-zero data: `finished.final_zero` is required in every context. The auditor checks its exact transport/group/service/gate keys, complete empty transport records/pins/tokens arrays and group groups/pins/tokens/probes arrays, independent ledger sums, integer-zero public counts/bytes, unchanged limits, running transport lifecycle, and all service/gate zero fields. Owners are intentionally still alive before `finish/3`; their final monitor arrays must each contain only the original SUT instance monitor. Source basis: test `reload_zero/2` at 4460, snapshot constructors at 4818/4860, `UpstreamTransports.init/1` at 216 and `UpstreamGroups.init/1` at 442. It does not incorrectly require these intentional monitor arrays to be empty.

The inherited checks retain eight contexts and 200 events, 23 generations/context, 22 CAS replacements/context, exact entire cycle2-to-cycles3..22 vector equality, original request/completion/selected-resource links, physical retirement links, rollback/capacity charge sums and original holds, all six peer joins/context and aggregate counts. Active rollback has three real transport/group tokens; idle rollback has zero. The F1 source sequence now prepares and completes NEW health before dispatching OLD active requests; rollback still observes those actual OLD tokens before CAS.

Expected aggregates remain 184 generations, 368 distinct transports/HEADs/seed GETs/retirement receipts/physical closes/accepts, 176 replacements, 264 held GETs, 632 GETs, 1000 requests, 184 group removals and 48 peer joins. Capacity checks cover 16 original holds. Command provenance checks pin candidate2 and its 402-entry actual command source map, exact argv/cwd/environment, stable before/after source maps, collector/log hashes, clean nonzero ExUnit counts and actual joined/nonforced process cleanup. Genuine adopted-child raw wait statuses remain unchanged and are decoded for reporting. Browser/Python/static counts stay separate.

DATA and source assertions have separate roles. The audit independently checks emitted arrays, statuses, numeric sums, identity lineage and peer frames. Frozen source asserts original completion awaits, normal monitor waits, processed cancellation, absence of unexpected peer effects and actual ETF serialization sizes. Those operations are reported as source attestations; they are not speculative evidence gaps or new acceptance requirements. DATA PASS does not claim that this auditor independently replayed them.

Candidate1 outputs remain immutable. The proposal pins candidate2's exact hash/kind/test hash and requires its added final-zero schema. Parent owns independent SPEC then CODE review, syntax qualification and execution. This handoff makes no runtime, SPEC or CODE acceptance claim.

No lookup errors or repair-and-validation rounds occurred in this assignment. Received counters were root259/orch168/group14, with the two prior lookup errors awaiting the supplied supplement root261/orch170/group16; Astra2/2 remains exhausted. No counter was reset or changed here.
