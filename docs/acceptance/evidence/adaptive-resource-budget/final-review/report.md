# ARB-FINAL-ACCEPTANCE

DONE for the assigned independent final integration/requirement audit. **Ready for versioned-source qualification.** No unaddressed actionable implementation finding was established. The earlier V15 ordinary connection-churn gap and H3/native-lifetime review findings are resolved within the inspected scope. Whole-goal delivery remains OPEN until the parent completes final versioned-source, package, Phoenix/client, standalone and public-publication gates.

Direct read-only Sol assignment; reviewer Sol0/Astra0, no escalation. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy`, existing `main`, reviewed baseline `bc8a5ef5199293ada3b432c2e2741070d3b2d115` plus preserved integration; original objective baseline `a6a35438c0a153cd53c87c6a55c19a70a11fb75a`. Only this audit directory was written. No source/test/docs/manifest/Git/dependency mutation, shared build, test execution, runtime, protocol peer, listener or network operation was performed by this reviewer. All reviewer commands are terminal. Implementation counters remain historical CORE Sol2/Astra6, H1H2 Sol2/Astra16, H3 Sol2/Astra12, churn Sol1/Astra0. Fixed deadline remains 2026-10-30T02:09:44Z.

## Verified evidence and reviewed integration

Paths below are relative to `.audit/adaptive-resource-budget/` unless stated otherwise. `receipt.json` binds raw receipt/log hashes and current implementation fingerprints. Counts describe existing terminal commands that the reviewer verified, not tests rerun by the reviewer.

| Key | Existing actual evidence | Scope |
| --- | --- | --- |
| ALL | `qualification/parent-final-all.json`: exit0, 120 exact per-file commands and 120 positive summaries, **868 tests/0 failures/0 excluded/0 skipped**, terminal | Canonical unit390 in54 files; component321 in28 files; protocol157 in38 files. All681 inputs unchanged during command and matched at review start. |
| STATIC | `qualification/parent-final-{inventory,format,compile}.json`: exits0, terminal, matching681-source fingerprints and raw logs | Current inventory and global formatting/strict compilation checks. |
| HARNESS | Four `qualification/parent-final-harness-*.json`: 8+9+5+14 = **36/0**, terminal exits0 | Script regressions only; separate from868 app cases. |
| H1 | `h1-h2/time-quota/final-review/{report.md,receipt.json}`: no actionable findings, all15 differential paths match current source | Previously independent reviewed H1/H2 source. Later CORE/native reference changes are covered by H3, not concealed as unchanged context. |
| H3 | `h3/time-quota/native-final-review/{report.md,receipt.json}`: native P1/deadline P2 resolved; candidate99/0 H3 +134/0 CORE/helper | Twelve of13 changed paths remain byte-identical. Remaining ConnectionTest is exactly the reviewed source plus its authorized unit tag. Before the separately authorized version-only metadata edits, full680-input context changes were only that annotation and two manifests; the new churn path adds input681. |
| CHURN | `churn-installed/churn-focused-repair1.json`: **16/0**, terminal exit0 | Controlled ConnectionTest13 plus3 actual protocol cases, nine finite fresh-connection rounds. ALL freshly includes all16. |
| PHOENIX | `qualification/parent-phoenix-mixed-{diagnostics,compatibility}.json`: **3/0** and **19/0**, terminal exits0 | Actual Phoenix mixed adaptive H1/TLS-H2/H3 and body/SSE/LiveView/WS scoped evidence; rerun final versioned-source example/client gates after later native ownership changes. |

New churn source was independently inspected in full. Each protocol starts one unchanged server with `max_connections: 1` and omitted `max_bytes`, then opens three new client executables/transports with distinct endpoint workers. Before release, positive live bytes and exact connection/request/H2/H3 stream counters are required. Each response must be HTTP200 with the exact requested path. Completion must occur while the connection is still open; only then does the test explicitly close the peer, require its clean exit and require zero public usage, memberships, leases, pending process credits, retained bytes and cleanup pending/failed state before reopening. Service generation/address/port must remain unchanged. H1 alone allows zero idle carried bytes; active-request positive bytes and all final-zero assertions remain intact. The earlier16/1 fixture failure is retained.

Churn is correctly `:protocol`: it creates real listeners, subprocesses and independent Python H1/H2/H3 peers. Existing ConnectionTest is correctly `:unit`: pure protocol/Options state, ETS, controlled workers and one isolated budget-less Admission, with no real socket/listener/client or complete multi-component runtime. Existing assertions and the only annotation delta are preserved. Canonical counts and retained-inventory promotion agree.

Inspected native integration agrees with the accepted review: Service-authenticated native reservation precedes handler initialization; canonical split preserves bytes and actual connection membership; callback and native lifetimes retire independently; only exact original-handle public closed evidence plus authenticated receipt/guardian termination permits refund. The final core/helper and ALL receipts include the previously failing persistent H3 SSE and native lifetime paths. H3 progress stays bounded by existing turn counts and absolute callback deadlines. H1/H2 accepted source remains unchanged. Public resource-budget docs accurately separate VM-local coordination, explicit undoubled service limits, native-byte/accounting scope and unavailable inspection from zero usage.

## Twelve Definition-of-Done rows

IMPLEMENTED means current source and current canonical/scoped evidence support the product behavior. It does not imply final selected-version/publication acceptance.

| DoD | Required outcome | Concrete current coverage/evidence | Disposition |
| --- | --- | --- | --- |
| D1 | Default soft50% of reliable effective capacity | `system_memory_test`, `resource_budget_policy_test`; Linux public snapshot and actual Phoenix thresholds; ALL/PHOENIX | IMPLEMENTED; native macOS/Windows execution NOT RUN. |
| D2 | Unknown capacity falls back256MiB | Exact soft268435456/hard536870912 fallback, malformed/unavailable/overflow detection cases; ALL | IMPLEMENTED. |
| D3 | No listener/instance budget multiplication | OWNER multiple-instance/racing gates; native ListenerSets; actual two-Endpoint/mixed listener public VM totals; ALL/PHOENIX | IMPLEMENTED; final versioned Phoenix gate pending. |
| D4 | Through100% NORMAL | Exact policy/OWNER100% boundary; ALL | IMPLEMENTED. |
| D5 | Above100% through200% admits with rate-limited warnings | OWNER committed state and shared warning/log-rate tests, exact200% acceptance; ALL | IMPLEMENTED. |
| D6 | Above200% new work refused atomically | OWNER projected races/overflow; Admission canonical operations; H1 safe503, H2 local refusal/live sibling, H3 0x107/live sibling; ALL | IMPLEMENTED. |
| D7 | Strict protocol/OOM boundaries remain | Safety stale/malformed/current/high/process/headroom races; H2 predecode/backing/receive bounds; H3 finite native/stream/flow guards; ALL and accepted source reviews | IMPLEMENTED within ordinary controlled/network scope; no physical OOM/pressure injection claimed. |
| D8 | Dynamic connection/request memory accounting | H1 independent connections/keepalive/partial uploads; H2 decoder peak/retained state/concurrent bodies; H3 typed native ownership; ALL | IMPLEMENTED. |
| D9 | Real completion relinquishes ownership | Terminal pair/guardian/proof permutations; H1/H2/H3 zero cleanup; newly independent reviewed churn9rounds; ALL/CHURN | IMPLEMENTED; V15 gap closed. |
| D10 | Phoenix H1/H2/H3 concurrency within capacity | Actual adaptive two-TLS-H2-connections/3held-streams and mixed H1/H2/H3 tests; native H3 two overlapping streams; ALL/PHOENIX | IMPLEMENTED scoped; final current-version actual Phoenix/unified clients pending. |
| D11 | Explicit configs compatible or documented migration | Config/activation/provider/OWNER/Admission cases; exact explicit max_bytes/max_active and separate quotas, docs/resource-budget.md; ALL | IMPLEMENTED; final package/isolation/versioned compatibility pending. |
| D12 | Telemetry/tests/docs/release metadata truthful | Numeric public counters/categories/reasons/rate limits and canonical manifest; reviewed public docs; ALL/STATIC/HARNESS | IMPLEMENTATION VERIFIED; metadata alignment, final acceptance-doc refresh, commit/push/release/public read-back still parent-owned and OPEN. |

## Twenty original verification rows

| Verification | Actual coverage/evidence | Current disposition |
| --- | --- | --- |
| V1 Supported-platform detection | Injected Linux/macOS/Windows detection and supervised native probe ownership; actual Linux execution in ALL/PHOENIX | Deterministic/Linux PASS; real macOS/Windows native execution NOT RUN. |
| V2 256MiB fallback | Exact policy fallback and failed/unavailable/malformed detection cases; ALL | PASS. |
| V3 50% calculation | Half/odd/finite-max pure assertions and actual Phoenix thresholds; ALL/PHOENIX | PASS; final versioned example repeat pending. |
| V4 100% boundary | Exactly100 normal/+1 warning and committed transition cases; ALL | PASS. |
| V5 Admit100..200% | Policy/OWNER concurrent projected commits and exact200 acceptance; ALL | PASS. |
| V6 Reject above200% | Exact200+1 refusal, unchanged state on refused canonical mutation, H1/H2/H3 wire refusals; ALL | PASS. |
| V7 Release/automatic recovery | Capacity shrink/release/readmission; two gates; H1 overload recovery, H2 expired-start same-connection reuse; ALL | PASS. |
| V8 Independent H1 connections | `resource_budget_h1_test`: distinct overlapping workers and keepalive, positive counters/finalzero; ALL | PASS. |
| V9 Independent H2 connections | Promoted `http2_default_concurrency_test` and actual adaptive Phoenix TLS-H2 distinct connections/owners; ALL/PHOENIX | PASS scoped; final versioned example repeat pending. |
| V10 Concurrent streams on one H2 | `resource_budget_h2_test`: overlap/local refusal/live siblings/compression continuity; actual Phoenix held3streams/2connections; ALL/PHOENIX | PASS scoped. |
| V11 H3 concurrency | `resource_budget_network_test`: two held streams, third0x107 refusal, siblings/crash/drain/publiczero; actual mixed Phoenix; ALL/PHOENIX | PASS current canonical; final versioned mixed-client repeat pending. |
| V12 Phoenix LiveView/WebSocket | Actual example compatibility/default/configured cases; native H2 sibling and H3 large-payload/persistent WebSocket tests; ALL/PHOENIX | PASS scoped; final versioned actual/unified client gates pending. |
| V13 SSE and streaming | Native/helper persistent SSE, H2 lifetime, H3 WebSocket/stream lifetime, Phoenix keepalive/finite stream cases; ALL/PHOENIX | PASS canonical/scoped; original helper16/1 retained; final versioned example repeat pending. |
| V14 Concurrent request bodies | H1 two partial uploads and H2 overlapping body streams, exact echoes/membership lifetime; ALL | PASS. Phoenix body tests add parser evidence, not an invented upload count. |
| V15 Connection churn/cleanup | New churn3protocol cases x3fresh connections; unchanged server/generation/port; live positive usage, completion-before-close, clean peer exit, exact publiczero before next round; CHURN/ALL | PASS; previous G1 closed, nine finite ordinary rounds, no load/soak claim. |
| V16 Cgroup limits | v1/v2 ancestors/hidden hierarchy/unlimited/malformed/permission/overflow and safety current/high/headroom tests; actual Linux metadata; ALL | Deterministic/Linux PASS; no live limit mutation or real v1/v2 container matrix claimed. |
| V17 Instances/ListenerSets | VM-shared atomic OWNER, native multiple ListenerSets, two actual Endpoints/mixed roles; ALL/PHOENIX | PASS scoped; final versioned actual Phoenix repeat pending. |
| V18 Explicit/backward compatibility | Exact legacy transport/lease caps, omission provenance, independent quotas, explicit instance soft/hard and H3 options/backend cases; ALL | PASS canonical; final selected-version package/isolation checks pending. |
| V19 Crashes/cancel/drain | Canonical aliases/retry/generation/terminal pairs; H2 startup/retirement/peerclose/writer proof; H3 native registration ambiguity/guardian loss/terminal order/deadline cases; ALL and independent H1/H3 source reviews | PASS ordinary deterministic/network scope; specialist forced-writer/slow-peer/load remains unrun/out of scope. |
| V20 Telemetry/warning/rejection reasons | OWNER committed transitions/log rate limits/shared warnings; numeric Admission retained/temporary/usage highwaters and specific Safety/policy/quota reasons; ALL | PASS. |

## Parent-owned remaining gates and reporting

Final version metadata was also reviewed: all fifteen ARB-VERSION receipt hashes match; seven own manifests and six installation READMEs plus the Phoenix guide align0.14.0, with unchanged implementation/tests. Release notes and the Phoenix resource-budget guide preserve VM-local scope, exact thresholds, independent strict guards, explicit undoubled caps, quota defaults, cleanup lifetimes and unavailable inspection; no unsupported verification/publication claim is made. No new code repair, architecture decision, permission request or escalation is justified by this audit. Version0.14.0 metadata alignment is complete; the parent is qualifying that frozen source. Do not misdescribe the pre-version868 receipt as exact publication-source verification after changing versioned inputs.

1. Fresh required final-version canonical/static/Phoenix/source-client and protocol integration checks; package staging and clean built/source consumers with dependency/release isolation; source-built standalone core/gateway/H3 smokes. Follow existing release guards and serialized shared builds.
2. Refresh current acceptance/design/plan status and `docs/phoenix.md:348-351` (currently says runtime qualification is in progress) using new terminal evidence while preserving historical816/16, original mixed-Phoenix3/1, initial churn16/1 and prior failed recovery receipts. Current unchecked historical/current gate text is not itself a remaining implementation defect; final current status must become clear before delivery claims.
3. Task-owned conventional commit on current main, push/remote-SHA read-back and exact expected-SHA guarded coordinated six-package/standalone publication. Do not remove any guard or silently recover partial publication by redispatching an occupied version.
4. Fresh public Hex-only consumers, tag/source/main identities, GitHub assets/checksums/source/Hex byte comparisons and actual downloaded standalone runtime checks. Offline verifier controls are not public artifact/runtime evidence. Record hosted CI, local/source-built, public artifact and production acceptance separately.

Native macOS/Windows memory execution remains NOT RUN on this Linux host; portable HTTP smoke is not native memory qualification. Cryptographic attestation is not inferred from checksums or Actions byte equality. No production deployment/data/certificates, public management, Vault, browser automation, #97, sustained load, exceptional/slow-peer or pressure-suite expansion was performed or required. Stop at full verified authorized delivery or the fixed deadline. Reviewer writes stop at handoff.
