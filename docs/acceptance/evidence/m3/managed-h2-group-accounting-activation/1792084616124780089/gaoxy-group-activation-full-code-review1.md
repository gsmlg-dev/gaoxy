# Managed H2 group activation — full CODE review 1

Verdict: **REQUEST_CHANGES**. The complete A–F code/test review identifies three test findings below. No additional actionable production defect was identified. This is not accepted activation, a commit gate, or browser/runtime acceptance.

- Task: `/root/group_postactivation_code`; direct, independent, read-only review.
- Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
- Baseline: `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`; dirty/untracked task bytes identified by manifest, not HEAD alone.
- Frozen candidate: `docs/acceptance/evidence/m3/managed-h2-group-accounting-activation/1792084616124780089/postactivation-full-review-candidate1.json`, SHA256 `06c453b0a3f38fd1c008f5821491cff02809666b3c8c697d4965e2265dd8a4b0`.
- All **175 source identities match**, rechecked immediately before these reports. Hash authentication does not mean every unchanged compatibility file body was read. Complete primary stage production and stage-new/extended tests were reviewed, plus supporting public APIs, actual peer/browser HOST and compatibility boundaries. Exact input hashes and scope are in the JSON report.

## Findings

### F-CODE-01 — P1: Two-element legacy sys debug state silently removes the raw refusal observer

`apps/gaoxy_proxy/test/managed_h2_group_live_gap_test.exs` lines 285–304.

The legacy {debug,:unseen} install stores the callback return {from,operation} as {debug,{from,operation}}. On its next event OTP sys.erl:876 matches the keyed-debug clause before the legacy clause at889, treats From as Func, and catches badfun at887 by dropping this observer. Both real protocol cases time out waiting for group_gap_owner_refusal, although the normalized Session handoff is present. This prevents the intended live capacity-denial gate from passing.

Repair: Use an unambiguous tagged three-element tuple or map as the transient callback state, or an explicitly keyed install. Preserve exact raw owner From/operation/capacity correlation, normalized invalid_resource_pin/502, unchanged caps and all cleanup/sibling assertions.

Verify: Rerun both genuine handoff cases and the complete scoped live suite on the repaired frozen candidate; do not substitute pure callback evidence.

### F-CODE-02 — P2: Successful startup plus full cleanup attachment overlap lacks its required regression

`apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs` lines 57–160.

The four-protocol/downstream pairs test startup denial and attach denial only. No successful public path asserts an exact real request lease retaining startup5963776 while the full16478862 cleanup record is attached, followed by the args-owning helper return before the exact startup refund. The plan lines123-130 explicitly requires intermediate exact lease/cleanup totals. Browser exact_reservations validates cleanup attachment but neither the startup delta nor helper-return/refund ordering. Production HTTP:387-407 and654-674 appears to implement the intended order; this is a missing acceptance test, not an established production accounting defect.

Repair: Add a real public successful request regression for http2/h2c upstream and http1/http2 downstream. Observe actual authenticated Admission/Service intermediate lease and cleanup state and helper return/refund order, exact ordinary base plus5963776 and cleanup16478862, unchanged original G/T completion, final refunds/joins. Retain all current negative tests.

Verify: All four added successful cases must execute and pass with the complete startup gate; preserve assertions and finite barriers.

### F-CODE-03 — P3: Successful recovery test sends a duplicate continuation to the bare DynamicSupervisor

`apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs` lines 509–511.

The successful test resumes the recovery barrier at211 and removes its observer at213, then on_exit unconditionally resends continue_real_recovery at510. The supervisor no longer has the selective receive, so the fresh live log reports unexpected-message errors at5 and8. No product failure is inferred, but this is avoidable fixture noise and conflicts with clean gate reporting.

Repair: Track/join barrier ownership so teardown only releases a genuinely outstanding barrier and removes the observer once; do not suppress logs or weaken recovery checks.

Verify: Rerun the recovery cases and complete live gate with no duplicate continuation error messages.

## Complete stage coverage

| Area | Review result |
| --- | --- |
| A finite roles and schemas | Reviewed complete accountant, original backing/compact checks, finite proper list/map/tuple schemas, typed fixed/opaque exclusions and safe projections; no arbitrary-term encode before shape acceptance. |
| A arithmetic | P1048576 S2359296 L196608 N205337 K1183744 X131072 R205337 O1572864 A786432 W851968 I393216 U8192 E131072; phases5963776/5312512/7033906/5513216/3538944/3932160; group7033906 + fixed9444956 =16478862. No physical memory/mailbox/private dependency proof inferred. |
| B immutable group charge | Complete initial group ETF excluding bytes plus131072 growth, cap12582912; update revalidation preserves stable charge, exact stored refunds. Separate16777216 control ledger and probe/T/Service ledgers. |
| B controls before effects | Pin196608, selection/probe32768 provisional caps precede monitors/helpers/start effects, then reconcile actual bounded stored charge; owner snapshots and capacity/no-effect tests reviewed. |
| B resource cardinality | Per-provider64 handles, aggregate captured pins64/65536, each group33 dependencies preserved. No invented global33 or unique64 rule; first-occurrence order and aliases validated. |
| C startup | Startup5963776 reserved on real lease before neutral copy/child start; full cleanup16478862 overlaps until args-owning helper returns. Denial joins real inactive child; ambiguous unjoined cleanup drains/joins gate and does not claim retained lease after owner death. Required positive test gap F-CODE-02. |
| C public activation and authority | GroupEndpoint chooses ManagedH2Client from outset; internal activation is deterministic, no injectable bypass. Actual Service token, live resource pins, owner/instance identity and G/T admission precede open; structural tests are not authority. |
| C Session transitions | Neutral/start/init/selected/opening/bind/stream/cleanup states, raw roots, effective member limits and anchored deadline clamping reviewed. Payload dropping does not refund or discard original completion/tokens/pins. |
| C queued terminal controls | Both open/bind continuation mailbox checks preserve exact token/ref/PID authority and finite deadlines; post-bind cancellation checks before ready/upload; no replay or forged completion. |
| C control carriers | Lifecycle alias From, endpoint identity, handoff reply, actual cancel, timers, monitors, task/stream/delivery and Service controls validated with bounded original shape before their effects. |
| D Probe public path | Actual normal Probe reserve16478862, four probes65915448, claim/start/control preflight and original completion/T binding reviewed. Excess fifth probe does not start or change cursor/health; original cleanup gates retirement. |
| D recovery | Recovery preserves original RequestCompletion identity; G success may refund before helper DOWN, T retains until its own independent helper result/DOWN and completion. No stricter cross-owner order or helper-through-exit rule introduced. |
| E matrix | Real Python h2 peers and actual Gaoxy native HTTP1/2 downstream across TLS-H2/h2c reviewed: target/query escaping, ordered headers/trailers, raw compression, manual redirects, bodyless methods, upload/early final and healthy sibling progress. |
| E capacity | Real32 forwards, C2/R32/P0, exact527323584 cleanup hold and over-limit no-peer-effect refusal reviewed; owner capacity retains64-group behavior and payload-budget rejection before count cap. |
| E writes/lifecycle | Real stream reset, GOAWAY without replay, producer/pump/guardian death, consumed/cancel, gate/Service loss, committed-head deadlines, zero-credit timeout and partial native DATA failure with no ACK/success termination reviewed. |
| E failure honesty | Missing original Service is not zero. Unconfirmed HPACK/TLS cleanup retains failed G/T original records and charges through public stop; explicit forced test disposal follows failure observations and is not cleanup acceptance. |
| E fixtures/joins | Independent bounded peer preparations, actual TLS/ALPN/SNI, exact counts, physical EOF/reset and process joins reviewed; no fake peer success. Duplicate continuation teardown issue F-CODE-03. |
| E canonical browser | Actual Chrome/CDP shared mjs path uses native TLS-H2 and public GroupEndpoint HOST. Positive navigation/stream/early body/network and wrong-CA/name cases use real post-health GOAWAY/EOF and certificate rotation; only downstream test-SPKI trust is scoped. |
| E browser evidence | Raw G/T state observations, exact control/config sums and same-original identities, Admission sequence/fences, owner/observer/native joins, source-to-loaded-HOST checks reviewed. Browser3 has not executed on this candidate and remains NOT RUN. |
| F activation contracts | Stronger invalid/unauthorized/capacity refusal and real accepted paths replace old literal gate tests while preserving queued-terminal/no-open/no-bind assertions; fixed reserve9444956 unchanged. Actual refusal observer is broken: F-CODE-01. |
| Compatibility boundaries | H1 remains broader, group H2 profile stays homogeneous TLS-H2 or h2c with compact IDs/raw roots/exact H8; fixed H2 generation exclusion and standalone route protocol allowlist remain. H3 uses its separate client; group H2 classifiers avoid changing legacy fixed/H3 paths. |
| Core-only isolation | Proxy application owns its Session/Probe supervisors; core dependencies do not import proxy/H2/H3. external-consumer.sh copies only core and actual core consumer asserts absent optional dependencies and real TCP/UDP. Runtime still required. |
| Scope/custody | No dismissed http_fetch#97 replacement requirement; no dependency source patch, deployment/publication/Vault/public management/production data or disabled release-artifact E2E action. Full175 manifest authentication is distinct from content review. |

## Runtime evidence — separate from source verdict

Authenticated receipt and log hashes, exact175 before/after maps, joined status and command outcomes:

| Gate | Actual result | Receipt SHA256 |
| --- | --- | --- |
| fresh-format-1792095356109291264.json | PASS exit0; non-test gate; stable/joined, no timeout | `a312a0ff541a9945739a454809cf622db157ea7ddf2d41e2fe3f96d1de5aed76` |
| fresh-compile-1792095357652673708.json | PASS exit0; non-test gate; stable/joined, no timeout | `5141a1adf155a282d51fbac9bbbce62dfccaccd56caad3f4c8a231823a32b347` |
| fresh-group-live-1792095380140129955.json | FAIL110 tests/2 failures; exit2; zero skips/exclusions; stable/joined, no timeout | `01e16c00940596b60577ce070a09bfd60af8a10bf38539fc0d308f4e1f4ff3b3` |

The live log SHA256 is `63e6a218497f57da08834378cd7bbe69fac88a28c99841ce41d4db3242058981`. Its only two test failures are the genuine handoff refusal observers at `managed_h2_group_live_gap_test.exs:31` for http2 and h2c. The actual normalized Session handoffs are present. Guardian repairs passed their cases within this failing run; that does not pass the whole gate. Session46, browser3 and final pure/compatibility/standalone/core-only gates remain NOT RUN after this review/repair sequence. Historical passing commands stay historical.

Toolchain correction: an earlier reviewer message named OTP28.5.0.7. The authoritative fresh receipt resolves erl to `/nix/store/5y0714j8czhkjbmjb6l6m46n5w5fyr6q-erlang-28.5.0.5/bin/erl`. I read its exact `stdlib-7.3.0.1/src/sys.erl:876–901`; SHA256 `266f18abd9ba539c1da69e076844c4cfcf1162adc6fae1cf816e8be09411dd82`. It confirms F-CODE-01. No source-to-BEAM reproducibility is inferred.

## Custody and completion boundary

Reviewer Sol repairs: **0**. Parent failed GREEN attempts: **16**; ordered root repair events at frozen candidate: **16**, with ledger4 pending from root. These counters measure different things and are not collapsed into one repair-round total. Astra **2/2 exhausted**, no third recovery. Historical reports/evidence remain unchanged; the earlier bounded handoff report inference is superseded only by this actual-path finding, without rewriting history.

Changed files: only these two new `/tmp` reports. No source/evidence/Git/index edits, tests, build, formatting or runtime writes. All reviewer read commands completed; root actors were untouched. The authenticated root command receipts report joined=true.

No new product decision is needed. Root should repair the three test issues, freeze/authenticate the new candidate, obtain independent review, and run the complete fresh prescribed gates. Stage remains **CONTROLLED_ENABLED_PENDING_ACCEPTANCE**, with live FAIL and browser NOT RUN.
