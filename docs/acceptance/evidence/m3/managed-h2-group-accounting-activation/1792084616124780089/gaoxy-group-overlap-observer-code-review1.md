# Managed H2 overlap and observer proposals — CODE review 1

Verdict: **REQUEST_CHANGES**, limited to two redundant release sends in positive-startup proposal. The three original findings are addressed in substance; runtime remains **NOT RUN**.

Task `/root/group_postactivation_code`, direct read-only assignment. Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. All175 frozen source hashes match. Targets reconstructed only in memory; every before/patch/after-before-formatter hash matches descriptor `/tmp/gaoxy-group-overlap-observer-repairs1.json` (SHA256 `116312c81f9526be4c3143cecbfc14945284b8500006faa57d22ad79137a0cd0`).

## Finding

### F-OVERLAP-CODE-01 — P3: duplicate positive barrier release

`apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs` proposed reconstructed lines167 and319 (`/tmp/gaoxy-group-positive-startup1.patch`).

The normal path explicitly releases at reconstructed line137, then the observer returns :done at312 and removes itself. The test after167 and observer on_exit319 unconditionally send the same continuation again. After a successful G.close the Gate is already joined, so these sends target a dead PID; on early failure they can reach an Admission gate with no pending barrier. Admission.handle_info(_,state) absorbs such messages, so no DynamicSupervisor-style error noise is asserted. They are nevertheless unnecessary duplicate release traffic in the repair of the same fixture-ownership class.

Repair: Delete both redundant after/on_exit continuation sends. Preserve the actual single release at137, caller monitor DOWN release at301, finite5000 barrier timeout at303, observer removal, trace cleanup and all new/old assertions.

## Source checks

| Check | Result |
| --- | --- |
| Identity/custody | All three patch hashes, current source before hashes and reconstructed in-memory after hashes match the supplied descriptor. All175 frozen candidate source hashes still match. No source/patch/report was overwritten. |
| F-CODE-01 | SOURCE_RESOLVED: tagged {:delegation,from,operation} is a3tuple, avoiding OTP legacy/keyed debug state ambiguity. Exact real raw From+operation+capacity correlation and normalized invalid_resource_pin/502 assertions remain intact. |
| F-CODE-02 substantive coverage | SOURCE_ADDRESSED: four actual public success cases cover both native downstream protocols and both upstream H2 protocols. ObservedEndpoint takes the real request pump/lease gate baseline. Keyed gate observer captures actual :ok output states for +startup and genuine Service attach. Assertions require ordinary lease+5963776 and cleanup16478862 simultaneously, exact total, same lease/token, false receipt and bounded high-water. |
| Helper-return/refund order | SOURCE_VALID: only authentic -startup Gate input is held; return tracing in the same pump proves start_group_session/5 returned {:ok,guardian,...} before adjust_bytes refund call. trace_delivered(:all) fences original trace messages. No fabricated replies/state updates; after release, actual Gate :ok output proves exact base lease and unchanged cleanup record, total base+16478862; complete trace history requires exactly one + and one -. |
| Genuine network and completion | SOURCE_VALID: manual real peer sees exact /startup-overlap?; G original token guardian equals actually created Session; public RequestCompletion equals Session original request completion. Actual200 response, original completion await, G.clean ledgers, peer no-extra-request and G.close actor/physical joins remain. Existing wider live suite independently checks same G/T originals; this proposal does not add a second explicit T-original assertion. |
| F-CODE-03 | SOURCE_RESOLVED: recovery debug barrier monitors original test caller and releases on exact DOWN or explicit matching continuation, demonitoring in after. on_exit only removes observer, no duplicate DynamicSupervisor continuation. Original recovery proof/assertions and finite @timeout unchanged. |
| Cleanup/deadlines | Five-second actual receives and existing fixture deadlines retained; parent DOWN releases held callbacks even if test exits before explicit release. Trace cleanup in try/after retained. New positive observer has redundant sends F-OVERLAP-CODE-01; no production mutation or diagnostic suppression. |
| Assertion preservation | No prior assertion is removed or weakened in any patch. Startup negative tests remain; only shared trace-pattern list extracted. All caps, real raw/norm refusal assertions, recovery and original completion assertions retained. |
| Runtime boundary | No compile/test/build/runtime command launched. All repairs are NOT RUN. Root reports fresh browser command joined exit1 FAIL with zero completed cases and stable source; not a patch finding and not a passed browser gate. No external/product decision needed. |

## Bound proposals

| Target | Patch SHA256 | Reconstructed after SHA256 |
| --- | --- | --- |
| `apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs` | `ed8257558ed40a6abcd69e1f004b99d0cd7ce225e5b42da56b0e032c4ce14ee4` | `ef0c18f261731b7e7120e9e56424737116774c05590ce986e48e7c173a4fdd23` |
| `apps/gaoxy_proxy/test/managed_h2_group_live_gap_test.exs` | `1d56547371d3f57236f2ec82172f80181a2a12425c60f9a4c7a85a60f12234bd` | `e0b4cbedf8b60e85626b3d57a1ab6bb76af9e666385605bcd86df4a58451c543` |
| `apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs` | `b3e785084468801078d82b53e04c6d8847d242af65d82afabb10e9f163542dd1` | `3c7550eb75f941ede344251630d519d0db05d71482f84db7df632d7e5dd78e70` |

No assertion weakening, dependencies, production source or public API changes. No source defect is inferred from the new browser failure: root reports joined exit1/FAIL, zero completed cases, stable source, diagnosis pending. This is separate from the live110/2 failure and cannot certify browser acceptance.

Reviewer repairs0; parent failed GREEN ledger16 plus one new unrecorded browser failure, root repair events16, Astra2/2 exhausted. Counters remain distinct and inherited. No runtime was launched by reviewer. All own commands finished; no actor or repository/index/Git/evidence bytes touched. Only these two new `/tmp` reports were written.

After removing the two redundant sends, retain the actual single release, monitor and deadline; run the real positive startup cases, existing negative cases, both handoff refusal cases/recovery checks and complete prescribed fresh gates on a new authenticated candidate.
