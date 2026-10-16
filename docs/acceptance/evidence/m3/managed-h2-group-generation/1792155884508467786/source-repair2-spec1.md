# gaoxy-group-generation-source-repair2-spec1

Status: **BLOCKED_HANDOFF**. Frozen version1 regression verdict: **FAIL (C1)**. Direct bounded SPEC/constructor review; no runtime acceptance.

Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
Branch: codex/m3-h1-resource-foundation
Baseline: 8131af39a846c292a022ccbfd32c53376cd57887

## Actionable finding C1

The version1 regression proves a noncompact raw `x-slice` header in the original native Exchange, but `HTTP.Headers.request/1` calls `normalize/1` before `group_request_options/5`; normalize copies all names and values. The short `/new-slice` target does not force a noncompact target at the changed constructor. The test therefore cannot demonstrate rejection by the old validate-before-copy branch.

Use a valid plain HPACK :path longer than64B and shorter than127B. Assert the actual original captured Exchange target equals the sent target and has logical bytes < referenced backing <=65536. Keep x-slice as the exact-forwarding witness and preserve independent accounting, completion and all joins. Root already announced this correction; this report does not review its current content.

## Production and constructor assessment

The only production repair switches `group_request_options/5` to the existing `prepare_group_source/1`. Original target/path/query/time/URL bounds remain. The preparer validates raw shape, grammar, original logical/backing aggregates and ETF cap before copies; strict retained validation remains unchanged in accounting/startup/Session/selected boundaries. The prior owner-reply accounting normalization remains exact. No actionable production issue found.

Prepared data retains the same closed six-key constructor and compact target/pairs, with no new cap/schema/provider/process/ref/timer/monitor/lifetime. The added raw operands enter existing original native95/P/N/W/B accounting. The frozen test keeps the two authentic providers, G7/T8 batches, old-generation retirement, completion, cleanup, original native/connection/Writer/owner/peer joins and rebind. This is bounded source evidence only.

## Evidence and checks

- Initial nine declared inputs plus proposal hash matched; branch/baseline matched.
- Prior sanitized diagnostic qualification/host/browser hashes matched. Absolute source_before/source_after HTTP keys both identify pre-repair SHA `76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98`.
- Historical browser diagnostic remains FAIL: one h2-h2c row, fresh native on same connection/Writer, strict source validation invalid, actual400 and `net::ERR_HTTP_RESPONSE_CODE_FAILURE`. Exact Chrome predicate remains UNKNOWN; no retrospective reclassification.
- Final hash check found root's announced test correction: `d880b64ffa62644b2e939c1b66b806d76ad88ae92ba66be05b026c01e4d15408` -> `c9ec261257168ca66ec33872f7994855d6e570ab3c731b102b7c8283f495ad0b`, while version1 proposal/design stayed fixed. Other20 inputs unchanged. A frozen version2 rebind is required.
- Runtime/import/tests/build: NOT RUN by assignment.93 expected initial combined tests is proposal-only, unexecuted. Independent CODE must follow source PASS; full-stage review remains open.
- One metadata-only relative-key lookup raised KeyError/exit1; suffix-based absolute-key recovery exited0. Root notified; no counter increment invented.

## Hashes

Original ten hashes were captured before review. Eleven additional supporting inputs were first hashed after bounded reads and then rechecked. Complete values:

| Input | Before SHA256 | After SHA256 |
| --- | --- | --- |
| apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex | dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31 | dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex | c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947 | c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947 |
| apps/gaoxy_proxy/test/managed_h2_envelope_test.exs | cbfa2487ad1191d32b7f9ec0d36bf00644e8b48d93db02f7bf62c41c14f2b338 | cbfa2487ad1191d32b7f9ec0d36bf00644e8b48d93db02f7bf62c41c14f2b338 |
| apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs | d880b64ffa62644b2e939c1b66b806d76ad88ae92ba66be05b026c01e4d15408 | c9ec261257168ca66ec33872f7994855d6e570ab3c731b102b7c8283f495ad0b |
| apps/gaoxy_proxy/test/managed_h2_group_source_test.exs | c998127c7690f04f0b303be40991f91528b1bd39676cd6aa30e57bf6d9ea31cb | c998127c7690f04f0b303be40991f91528b1bd39676cd6aa30e57bf6d9ea31cb |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-diagnostic1-classification.json | 1c0aace9f9fa4fdafb829f08bd9cac87ef612f877cfe23c12b44fd8cba119d33 | 1c0aace9f9fa4fdafb829f08bd9cac87ef612f877cfe23c12b44fd8cba119d33 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-design.md | 6d1fc736578e4db538e2d546429ff0c39b06544d9731a25dcaaac48e97be8216 | 6d1fc736578e4db538e2d546429ff0c39b06544d9731a25dcaaac48e97be8216 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-http-before.ex | 76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98 | 76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-proposal.json | 44b9c9f98aa9c8fd93a9450fa7ee20b5f19b4ab81f275f063b43c810f5dae07b | 44b9c9f98aa9c8fd93a9450fa7ee20b5f19b4ab81f275f063b43c810f5dae07b |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-before.exs | 489ae6a6617e52c3c7d42a06a5b0cd8e8170ed0ba5b2fd53c6c6b91a298cc23b | 489ae6a6617e52c3c7d42a06a5b0cd8e8170ed0ba5b2fd53c6c6b91a298cc23b |
| apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex | 586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52 | 586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52 |
| apps/gaoxy_http/lib/gaoxy/http/http2/frame.ex | 319d286ef3d9bbe1185ae93b51f8e9af090c02b438de8c1f45118f7300016f9d | 319d286ef3d9bbe1185ae93b51f8e9af090c02b438de8c1f45118f7300016f9d |
| apps/gaoxy_http/lib/gaoxy/http/http2/headers.ex | a3908c7ba3c61a90b78537ce58d062ac188d0f741972064b34bb4bdf58f24090 | a3908c7ba3c61a90b78537ce58d062ac188d0f741972064b34bb4bdf58f24090 |
| apps/gaoxy_http/lib/gaoxy/http/http2/limits.ex | f8d922deee2f7a45ecf3070498a3f82a50af47b5fbe0007545ab11bf3cf831ab | f8d922deee2f7a45ecf3070498a3f82a50af47b5fbe0007545ab11bf3cf831ab |
| apps/gaoxy_http/lib/gaoxy/http/http2/transport.ex | 9c135f7dad3918f8c2ef4375aecc5a3eb99a536ffa9ea36a9f866747221e5c5a | 9c135f7dad3918f8c2ef4375aecc5a3eb99a536ffa9ea36a9f866747221e5c5a |
| apps/gaoxy_http/lib/gaoxy/http/http2/worker_accounting.ex | 3ee7f96df0c1394d25354280f77bba71ae59defd6fd252702f1847fcf58b78a7 | 3ee7f96df0c1394d25354280f77bba71ae59defd6fd252702f1847fcf58b78a7 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex | 03fb7c9e22b4ca7b64c8967cf0c06f8e964897fc6ab400b76cd39fe361f13d91 | 03fb7c9e22b4ca7b64c8967cf0c06f8e964897fc6ab400b76cd39fe361f13d91 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_group_accounting.ex | 933b07a056d3a80baa6ce9ff9df1c84d7b4fc24c49dde1770d16f8855a6ee92f | 933b07a056d3a80baa6ce9ff9df1c84d7b4fc24c49dde1770d16f8855a6ee92f |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-diagnostic1/h2-h2c/browser.log | c47880421c9e6d16d18c7f06aca8f86fc9631d859132064cd0d98a8c5886cb35 | c47880421c9e6d16d18c7f06aca8f86fc9631d859132064cd0d98a8c5886cb35 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-diagnostic1/h2-h2c/host.log | ad0a0642603c953230f35c96448dc739ee58d5a04cd969e9c9f2e8573820e750 | ad0a0642603c953230f35c96448dc739ee58d5a04cd969e9c9f2e8573820e750 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-diagnostic1/qualification.json | c6b9ba92c5edf1402f3f320ca2be0678a29fad8b439374794341c00e5c097e45 | c6b9ba92c5edf1402f3f320ca2be0678a29fad8b439374794341c00e5c097e45 |

## Counters and shutdown

Received frozen counters: group failedGREEN51/root97/orchestration29; stage failedGREEN6/productionRepair2/fixtureRepair7/orchestrationRepair22; Astra2/2 exhausted. Reviewer repair rounds0. Metadata read-event update pending root; these received counters were not reset.

Only the assigned two /tmp reports were written. No repository/evidence/Git/runtime/network/agent writes/actions. No private raw trace/NetLog/key reads. All own commands ended synchronously; no live command/session/process. No product decision or permission needed: root must freeze/rebind version2 and counters. Publication/deployment/full-stage acceptance remain outside this verdict.
