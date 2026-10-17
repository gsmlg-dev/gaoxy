# Idle capacity failure diagnosis1

**Source-supported phase race; actual failure state still unknown.** The code proves that both held OLD transport retirement inputs do not establish that Store released the OLD group baseline or finished its retired list. The first run does not emit failing G/Store state, so the race remains a cause hypothesis pending the parent's observation-only candidate.

Direct read-only assignment in `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, supplied baseline `e4a7660baa61a792f4245f511b190a0fcfcbf920`; current source pin remains `144ff05c2de10f600c9776565711f1072e08e8487b914c5c42250118230ff535`.

## Observed

Actual first receipt reports exit2,104 executed tests/8 failures, source stable with no changes, nonforced joined process. Four idle contexts fail at cycle3 `reload_capacity/4` line4141: the compound predicate requiring exactly one group and the fresh key is false. Actual Gcount2, OLD key presence and Store.retired contents are **not emitted** and must not be claimed as observed.

All four actual preceding cycle2 inventories list baseline batches in order `[T,G]`. Their snapshots show Ggroups1/pins1/tokens0/probes0 and Store.retired0/preparationnil/baseline_batches2. These are the preceding settled observations, not the failing cycle3 state.

Control flow reached4141 after both exact held messages and the original actual T checks passed: resources4/pins2/request_tokens0/helpers0/reserved_connections8/failed_resources0, exact OLD+NEW records, original OLD records closed/charged/unconfirmed with retirement requested and live custodians. No capacity-refusal success or cycle3 plateau success follows from reaching this point.

## Source causal trace

1. Test `activate` lines1458-1474 waits for coordinator success/normal DOWN, verifies the fresh router and fresh baselines. It does not assert OLD G absent or Store.retired empty.
2. `Gaoxy.HTTP.Generation.Store` activation lines528-540 installs fresh baseline/router and queues the actual old baseline through `retire_pins` lines607-612. The actual old order observed at cycle2 is `[T,G]`.
3. Store `handle_info(:reconcile_resources)` lines572-580 releases **one pin per turn**. On success it removes that pin and schedules another zero-delay timer for any remaining pin.
4. T `handle_call({:release,...})` lines380-400 calls `remove_pin`1102; `close_unpinned`1117 and `retire_resource`1148 mark CLOSED/requested, send the real retire messages to custodians and return. They await neither G release nor Store.retired empty.
5. Test observer lines3729-3750 reports/holds each original custodian input before retirement processing. Both held inputs establish a T phase only.
6. G release lines575-591 invokes `remove_pin`931-940 and `reconcile`1041-1083. G is deleted only when no pins remain, inflight is0 and matching probes are absent. A remaining baseline keeps the group unchanged.
7. Idle cycle invokes capacity immediately after activation and before the normal retirement joins (test3674-3677). Capacity reads G and asserts NEW-only without a G/Store settled barrier.

A legal schedule therefore releases oldT, lets both custodian holds reach the test, and snapshots G before Store's next turn releases oldG. Zero-delay timers provide no ordering guarantee across these actors. This source path explains how the T checks can pass while the next G predicate is false, without demonstrating the actual failing Gcount.

If the next observation shows Store.retired empty but OLD G retained, inspect its authentic remaining pin kinds/holders, inflight and probes. That would be a different pending anchor/effect than the hypothesized unreleased baseline. The first output also cannot identify which operand of the compound predicate failed. No product defect, permanent leak or dependency issue is established.

## Conditional repair proposal

First capture actual before-failure G and Store snapshots and validate the cause. Only if that supports the phase hypothesis, add a small explicit G/Store settled barrier inside the existing capacity try after both held-input timestamps are received. It observes the exact original NEW-only group and settled Store predicates, then retains all existing assertions and the actual capacity transaction.

Use a single absolute deadline `min(original held-start timestamps)+2000ms`. State queries and polling use its remaining budget; no fresh5000ms/resettable wait. The existing transaction and through-continue assertions still require every original hold's elapsed time below2000ms.

The barrier must observe both actors: G contains exactly the fresh group, OLD absent, one pin and no tokens/probes; Store has the fresh router, nil preparation, empty retired, two baseline batches and the exact fresh G/T handles. G removal does not require OLD T retirement completion after its final anchor disappears, so this phase can settle while both genuine custodian inputs stay held.

Preserve all original resources4/pins2/reserved8/tokens0/helpers0 checks, exact four resource identities, charged/unconfirmed OLD records, public fifthT refusal, exact before/after T no-delta, NEW-onlyG1 assertions and original2000ms clocks. Keep the existing `after` sending **both** original continues on any outcome. Do not add an arbitrary sleep, change production modules, free OLD resources early, replace retirement inputs or weaken assertions. This is a proposal only; no fix was applied.

## Evidence and limits

| Input | SHA256 |
| --- | --- |
| group test | 144ff05c2de10f600c9776565711f1072e08e8487b914c5c42250118230ff535 |
| HTTP generation.ex | 4eeaa5bb6bcc65d181cec52a7fbcd9344c7d327746ef9ec8a10cec0a3cb7630c |
| upstream_groups.ex | e98dea5d0769258838c0c53b397da4740d0b6f303c02d1c13cf712cb32a645c9 |
| upstream_transports.ex | 877bb6e4c891ee3f8c93a425a67b10f390137fcead2eeb52ccd9b78d9b2b1f51 |
| E6/group-reload-first-scoped1.log | d4ea55ba24a79fde41e1ae368e85ee3849d66e838d4d909404acf58e571e0a0c |
| E6/group-reload-first-scoped1.json | 0a680822099b74a8e4d5833892f747c107dbafe281be0585d5e68fe15f130753 |
| E6/first-runtime-failure-audit1.json | 1eccfcf053f170e2404d52081420e6d46ea0da2af85894aa784961fa59ccaf41 |

E6 is `docs/acceptance/evidence/m3/managed-h2-group-reload-plateau/1792240357368527898`. All pins freshly checked. Bounded jq projections were used for original cycle2 observations; no reviewed code or proposal was executed. Reviewer ran0 tests/build/runtime/browser commands and made no repository/evidence/source/Git changes. Four active failures are outside this diagnosis.

Two tooling incidents were promptly reported: one rg exit2 from two guessed nonexistent proxy module paths, followed by locating/reading actual HTTP generation.ex; one accidentally oversized log output truncated by the tool, replaced by bounded projections. No conclusion relies on omitted output. Received counters root265/orchestration172/groupTool18/groupRuntimeFailedGREEN1; Astra2/2 exhausted. Reviewer adds0 repair rounds; parent owns cumulative tooling accounting. All own commands finished and no runtime/background process was started or touched. Only the two assigned `/tmp` reports were written. No user decision is required.
