# gaoxy-group-generation-source-repair2-spec3

**DONE — PASS (bounded fixture correction and rebind only).** No actionable findings. No full-stage/Task5/M3 acceptance.

Direct read-only SPEC3. Worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation
Branch: codex/m3-h1-resource-foundation; baseline: 8131af39a846c292a022ccbfd32c53376cd57887 (parent confirms unchanged; no Git operation run).
Proposal3 SHA256: f3a43673aefdd9efc3093b5cabc2f05944e2bd3652b770fac91053019aef2c57

## Correction and actual state evidence

My SPEC2 review missed that the wait accessed nonexistent `state.startups`. Actual RED1 failed before stream3, so it supplied no production-boundary regression proof. That result remains **FAIL_INVALID_REGRESSION**; earlier source review is not a substitute for execution.

The complete diff from immutable version2 is one new-test operand: `state.startups == %{}` becomes `state.starting == nil`. `HTTP2.Connection.init` initializes `streams: %{}` and `starting: nil` (lines50/53). `start_next` sets the scalar to the stream ID and stores startup under `streams[id]` (539–575); dispatch clears scalar/startup (1222–1225), and discard deletes the stream and clears its matching scalar (1375–1376). The correction checks the real required key directly, without a default or bypass.

The same wait still requires streams empty, original native disappearance and removed original Gate lease. Exact110-byte target/logical<backing<=65536, auxiliary header/exact forwarding, original connection/Writer, authentic G7/T8, real completion, native95 P/N/W/B, cleanup/normal joins, finite deadlines and all caps remain byte-for-byte unchanged. HTTP SHA remains `dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31`. No production change is introduced.

## Preserved RED1 evidence and plan

Bound RED1 classification reports93 tests/2 failures/exit2; both new tests fail with KeyError :startups before stream3. Receipt remains `INTENDED_RED_REQUIRES_ASSERTION_AUDIT`; audit remains FAIL_INVALID_REGRESSION. Actual receipt shows skipped0/excluded0/warnings[], stable source/no changes, joined process/nonforced/no wait error, empty remaining process group/descendants and no signals. Exact pre-repair HTTP/test hashes remain fixed before/after; restoration receipt and current active hash identify exact reviewed candidate HTTP. This is invalid regression evidence preserved, not an accepted RED.

Plan passes bounded review: SPEC3 → independent CODE2 → new exact pre-repair stable-source expectedRED2 with actual assertion audit and finally exact-candidate restoration → fresh unfiltered93 initial4 → four browser rows/eight viewed images → full-stage SPEC/CODE and all final gates. These new executions are NOT RUN at this freeze. Historical browser FAIL/unknown rejected input remain unchanged.

## Complete manifest rebind

All28 declared inputs and proposal3 matched before review and stayed unchanged after (29 input pairs). Prior reports/snapshots/invalid RED are preserved.

| Input | Before SHA256 | After SHA256 |
| --- | --- | --- |
| apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex | 586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52 | 586db509de60712be04f5c7290adfbc6db31300a592344d54cf28e3872d24c52 |
| apps/gaoxy_http/lib/gaoxy/http/http2/headers.ex | a3908c7ba3c61a90b78537ce58d062ac188d0f741972064b34bb4bdf58f24090 | a3908c7ba3c61a90b78537ce58d062ac188d0f741972064b34bb4bdf58f24090 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex | dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31 | dd04efd4b255f7b03a4f68d23ac6cabcca3b9be0fb1a9a431cd24df960b11c31 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/http/headers.ex | 03fb7c9e22b4ca7b64c8967cf0c06f8e964897fc6ab400b76cd39fe361f13d91 | 03fb7c9e22b4ca7b64c8967cf0c06f8e964897fc6ab400b76cd39fe361f13d91 |
| apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h2_envelope.ex | c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947 | c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947 |
| apps/gaoxy_proxy/test/managed_h2_envelope_test.exs | cbfa2487ad1191d32b7f9ec0d36bf00644e8b48d93db02f7bf62c41c14f2b338 | cbfa2487ad1191d32b7f9ec0d36bf00644e8b48d93db02f7bf62c41c14f2b338 |
| apps/gaoxy_proxy/test/managed_h2_group_generation_test.exs | e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa | e80503bb68521d29fa3423a3c93c9059598d0602eec1858cd1c751aba759a2fa |
| apps/gaoxy_proxy/test/managed_h2_group_source_test.exs | c998127c7690f04f0b303be40991f91528b1bd39676cd6aa30e57bf6d9ea31cb | c998127c7690f04f0b303be40991f91528b1bd39676cd6aa30e57bf6d9ea31cb |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-command-collector3.py | 008687f0d21470e8fcb4fcf6cca3f46b86b9e3cec394ead06a14106899f9a0c5 | 008687f0d21470e8fcb4fcf6cca3f46b86b9e3cec394ead06a14106899f9a0c5 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/browser-diagnostic1-classification.json | 1c0aace9f9fa4fdafb829f08bd9cac87ef612f877cfe23c12b44fd8cba119d33 | 1c0aace9f9fa4fdafb829f08bd9cac87ef612f877cfe23c12b44fd8cba119d33 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/command-collector3.py | aeff8b310f5f0a296ed79d915d9f8beb4f57b2e2d782a857de85779c298d27ee | aeff8b310f5f0a296ed79d915d9f8beb4f57b2e2d782a857de85779c298d27ee |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-host3.exs | a3dd5731a954f509ed724fa77910eb9ab377466f0c03d7434cf3444997eb51a4 | a3dd5731a954f509ed724fa77910eb9ab377466f0c03d7434cf3444997eb51a4 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/group-generation-browser-runner3.py | 7739650e7b07f0b25448bf32a5f2c36e875f4efbd136645747429d94a3038757 | 7739650e7b07f0b25448bf32a5f2c36e875f4efbd136645747429d94a3038757 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-code1.json | 49cf59836effaccc586612233578b053913cb5d7ea0dd21b3dcc77679cebb7c3 | 49cf59836effaccc586612233578b053913cb5d7ea0dd21b3dcc77679cebb7c3 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-code1.md | 9be5832e9c8deb1f2f954faf6dcdf84d67fa03f4cd135d54157d1e81ec81d558 | 9be5832e9c8deb1f2f954faf6dcdf84d67fa03f4cd135d54157d1e81ec81d558 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-design2.md | d7ec684f22efc7d09762014d1dd40f9032b530a4bb67ac86b4f188f6e146a2f9 | d7ec684f22efc7d09762014d1dd40f9032b530a4bb67ac86b4f188f6e146a2f9 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-design3.md | 75eddd92b2d3390fc69f8e2ca8e010e1e508305a7e6992aad71fc59d8acc33ed | 75eddd92b2d3390fc69f8e2ca8e010e1e508305a7e6992aad71fc59d8acc33ed |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-http-before.ex | 76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98 | 76ec5ad7e9cf3c986b8da97be191fd7463a417cc0a4d5851f8bdf209004ddb98 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-proposal3.json | f3a43673aefdd9efc3093b5cabc2f05944e2bd3652b770fac91053019aef2c57 | f3a43673aefdd9efc3093b5cabc2f05944e2bd3652b770fac91053019aef2c57 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red-restoration1.json | 0758587b2575278ce47210a2eac8868965d2f803f3b1c879256decf3ebb8fbc7 | 0758587b2575278ce47210a2eac8868965d2f803f3b1c879256decf3ebb8fbc7 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red1-classification.json | ca8257cb6d21e8f80d6bcfcb5a3d588c0e4d4a437596a597adb4d2757940910f | ca8257cb6d21e8f80d6bcfcb5a3d588c0e4d4a437596a597adb4d2757940910f |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-red1.json | 1289624b1d40af7e00f66a0dd9b19e02346dac16c492006e8b18fc601dd9669b | 1289624b1d40af7e00f66a0dd9b19e02346dac16c492006e8b18fc601dd9669b |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-spec1.json | af6913e7fd81121589f8f45b967cfa4ed1405d3650e8fa75ba55a6c188d12475 | af6913e7fd81121589f8f45b967cfa4ed1405d3650e8fa75ba55a6c188d12475 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-spec1.md | 515dbecbfd3fb92aec19da6b8586a8ee02d69df09b6ec26b7ed805bc150be4df | 515dbecbfd3fb92aec19da6b8586a8ee02d69df09b6ec26b7ed805bc150be4df |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-spec2.json | 93759d1df0bfc1744cdb5f69894d0c23b724d3ad04a9424436ad990aff063414 | 93759d1df0bfc1744cdb5f69894d0c23b724d3ad04a9424436ad990aff063414 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-spec2.md | 4050c9c334838fc6f9642ca3aeba0091a2ec975a2083778c5b1cc2c341bfdcf7 | 4050c9c334838fc6f9642ca3aeba0091a2ec975a2083778c5b1cc2c341bfdcf7 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-before.exs | 489ae6a6617e52c3c7d42a06a5b0cd8e8170ed0ba5b2fd53c6c6b91a298cc23b | 489ae6a6617e52c3c7d42a06a5b0cd8e8170ed0ba5b2fd53c6c6b91a298cc23b |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-proposal1.exs | d880b64ffa62644b2e939c1b66b806d76ad88ae92ba66be05b026c01e4d15408 | d880b64ffa62644b2e939c1b66b806d76ad88ae92ba66be05b026c01e4d15408 |
| docs/acceptance/evidence/m3/managed-h2-group-generation/1792155884508467786/source-repair2-test-reviewed.exs | c9ec261257168ca66ec33872f7994855d6e570ab3c731b102b7c8283f495ad0b | c9ec261257168ca66ec33872f7994855d6e570ab3c731b102b7c8283f495ad0b |

## Counters, commands and limits

Received cumulative counters: group failedGREEN51/root105/orchestration35; stage failedGREEN6/productionRepair2/fixtureRepair9/orchestrationRepair28/invalidRED1; Astra2/2. No reset; reviewer repair rounds0.

Only the two assigned /tmp SPEC3 reports written. Python hashlib/json/difflib and scoped sed/rg reads all exited0 and completed synchronously before reporting. No repository/runtime/test/build/browser/Git/network/agents actions or live process/session. Independent CODE2 and every new runtime/browser/final gate remain open. No product decision or new permission needed.
