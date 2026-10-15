# Generation resource consistency — independent SPEC1

Status: **PASS_SPEC_SOURCE_TEST_NO_OPEN_FINDINGS**. Direct read-only review, task `resource_consistency_spec`. This approves the reviewed source/test specification coverage, not final documentation or complete stage acceptance.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`
Baseline: `8160e8bb6d7f55dc836b1aed0403cc2304a539bf`, branch `codex/m3-h1-resource-foundation`.

No actionable source/test requirement gaps. The adopted two-module change recollects exact normalized resource membership from compiled routes, recursively validates static Router sidecars, preserves compile behavior and immutable candidate terms, and inserts the check after generation hooks and before full-router byte acceptance/baseline acquisition. No init, provider custody/status, Store traversal, H2 qualification or global dynamic-budget expansion was added.

## Coverage

- **Five publication paths and all four valid-shaped sidecar defects** — new test lines135-158: public/direct/prepare via static Router/initial router/initial routes crossed with missing/extra/substituted/old_epoch.
- **Two static nesting levels with agreeing false outer/inner sidecars** — new test lines160-186 repeats full five-by-four matrix; Router77-79 recurses before reading nested sidecar.
- **Refusal before baseline/request custody changes** — new test setup107-133 acquires authentic old baseline and test-held request pin; helper446-452 compares exact public snapshot and full old/candidate provider ledgers;487+ releases request in original holder.
- **Generic metadata and five/six-key pin compatibility, exact immutable supplied Router** — new test220-252; acceptance uses original supplied Router and normalized duplicate/reordered handles.
- **Raw64/65 and ETF65536/65537 bounds** — new test254-303; unchanged Resources.validate; no normalization bypass of raw list count.
- **Compile behavior and once-only init** — new test305-349; Router56-62 preserves default compile collection branch; no compile/init in validator.
- **Legacy/empty static Router/malformed callbacks and targets** — new test188-218,351-368; collector rescue/catch maps raise/throw/exit and malformed nested values to finite resource error.
- **Dynamic Generation is opaque [] without Store traversal/global union cap** — new test370-394 uses two40-handle Stores then stops both before publishing dynamic candidate; unchanged Generation lacks resources callback.
- **Availability stays provider-owned** — new test396-417 matches route+sidecar unavailable handle, observes real provider acquisition/cancel and test_resource_unavailable.
- **generation_validate scope/order/precedence and other bounds preserved** — new test419-434 and existing generation_endpoint_validation tests; sole Generation insertion at445 after generation_bound and before full router external_size.
- **Exact normalized set and bounded resource-only scope** — Router43-54 uses MapSet.equal?; no provider APIs, owner status, Store/Registry traversal, new dependencies/processes, H2 qualification or reservations changed.

## Evidence audited

- Intended RED: actual FAIL/exit2,61 executed tests,47 exact rejection failures,14 compatibility passes. Independently matched log hash,47 failure headers/expected rejection assertions, zero fixture/compilation error markers. This is genuine missing-validation RED, not failed GREEN.
- Adopted/formatted GREEN1: actual PASS/exit0,61 tests/0 failures/0 skips/0 exclusions, finite600s,45.851971s wall, joined, process group absent,86 source guards identical before/after. Current reviewed source/test/document bytes match receipt. The exact Nix dirty-tree advisory is retained as an expected environment warning; no Elixir or unexpected warning is present. Root executed runtime; reviewer read actual receipt/log only.
- GREEN receipt SHA256: `f227ebe42003824a18a7393de6e1dc78ed6de6b9d0a974c385273715d3f78a8d`. Log SHA256: `54c9e2ba53fc5f05bbb86a63884af491004931f35495a14a2df5ef2d71613da0`.

## Interpretation and remaining gates

The parent accepted the interpretation that ordinary optional-callback detection attempts Code.ensure_loaded? and preserves absent/unavailable-module[] behavior. Normal compilation still validates endpoint availability; new forged-endpoint grammar is outside this slice.

Final documentation remains pending: clarify that interpretation, remove the stale preceding pending-browser phrase, and update kickoff-only NOT RUN/checklists against actual receipts. This is **not final document approval**. Remaining scoped gates, independent CODE review, fresh affected checks and disk/index/actual-commit custody remain parent-owned and are not claimed by this report.

No repository changes, runtime/build/formatter commands or Git mutations were performed by this reviewer. Only the assigned two /tmp reports were written. All reviewer commands completed; no reviewer background processes exist.

Counters unchanged: local0 failed GREEN/0 repairs; inherited24 failed GREEN/27 ordered root repair events; Astra2/2 retained/exhausted. No inferred global Sol-round count. No decisions needed. This slice neither completes M3 nor establishes later H2 Generation, browser/load, release/deployment or production acceptance.

## Reviewed byte identities

- `apps/gaoxy_http/lib/gaoxy/http/router.ex`: `513db9910d6f0beabf1038db8bc1539ee5c5e8731ace0f6d349b9f2f2db96abd` (6154 bytes)
- `apps/gaoxy_http/lib/gaoxy/http/generation.ex`: `aca3f62a1078825c1e6db087f76dacf2ab28611b5b360e2f14169f050ee9a751` (16917 bytes)
- `apps/gaoxy_http/lib/gaoxy/http/resources.ex`: `0e58a4f0badd2ba6d21b9f118c5b3f6c4d1070b4371e76e9dfc0656796f0907b` (2442 bytes)
- `apps/gaoxy_http/test/generation_resource_consistency_test.exs`: `8f0c73199483bc92eadf885e4ea1950c93ad1079520467de1cd0a2ce6faa9234` (19740 bytes)
- `apps/gaoxy_http/test/generation_resources_test.exs`: `8153e748b1815e7984401408d5705c197af9cecde1c2e40dd19418e6d88a2444` (8884 bytes)
- `apps/gaoxy_http/test/generation_endpoint_validation_test.exs`: `b54a53a266622e29bcd1992bc5411593222e2208534195373196bf87f2417ccc` (6104 bytes)
- `docs/designs/m3-generation-resource-consistency.md`: `9be4696e072b11a3596fe588eec25086f52a30d04cb66d982d155d67a5bdc913` (14052 bytes)
- `docs/plans/m3-generation-resource-consistency.md`: `3495ecb8ec43d064cf856d5253b3a60e9f11504a2f3560eac8ede77fb4a64c9c` (13201 bytes)
- `docs/acceptance/m3-generation-resource-consistency.md`: `b559ae7aae3cc57defb5089c0a15539ea28374417c20772f9ea35e954ebcc031` (1943 bytes)
- `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/kickoff1.json`: `25715b4828710ed57739786b89d2ee2564e5c23e1d8eab61411ffa40375acfc7` (5110 bytes)
- `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/intended-red1.json`: `a04e6587cc50d007cb82b64c40a8d6f3e144584fbd0384307118079bc0ec99ed` (58157 bytes)
- `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/intended-red1.log`: `d33126afa8ec694b9059a0f3f93d050e8ebe23dfde7dd924dd52d621280eb751` (51509 bytes)
- `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/intended-red1-interpretation.json`: `6fdb916dbfdae723af838e06de2a41e6234ff007123c1ef376ab45e7814c0579` (6860 bytes)
- `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/consistency-green1.json`: `f227ebe42003824a18a7393de6e1dc78ed6de6b9d0a974c385273715d3f78a8d` (58505 bytes)
- `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/consistency-green1.log`: `54c9e2ba53fc5f05bbb86a63884af491004931f35495a14a2df5ef2d71613da0` (1108 bytes)
- `docs/acceptance/evidence/m3/generation-resource-consistency/1792103327760528135/scoped-command-collector2.py`: `38afbabbbd11e88c3be4a109ec1c89e45893e3701937722bbc2da56892cd3376` (14708 bytes)

The companion JSON contains exact evidence/document hashes, coverage and pending gates.
