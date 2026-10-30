# ARB-ACCEPTANCE-AUDIT

DONE for this requirement-to-evidence audit; **whole-goal acceptance remains
OPEN**. One additional ordinary coverage gap was found: V15 finite connection
churn has no identified same-instance close/reopen accounting regression or
passing receipt. The parent acknowledged this bounded gap. H3 native lifetime,
SSE/WebSocket completion, final integration and delivery remain pending.

Direct read-only Sol assignment, Sol0/Astra0, no escalation. Repo
/home/gao/Workspace/gsmlg-opt/gaoxy, existing main bc8a5ef5199293ada3b432c2e2741070d3b2d115
plus preserved integration. Only this report and receipt.json were written;
no source/test/evidence/Git/build/runtime/network mutation or test execution.
All audit commands are terminal; writes stopped at handoff.

## Evidence key and scope

Paths below are relative to .audit/adaptive-resource-budget/. receipt.json
records each cited receipt hash, terminal status/exit evidence, parsed positive
counts and checked raw-log hashes. A passing historical scoped run is not a
passing current complete checkout.

| Key | Terminal receipt and exact evidence | Scope |
| --- | --- | --- |
| M | memory-final-review/receipt.json: focused53/0, exit0; source unchanged | Detection35, policy9, native-probe ownership9; independent review. Actual native macOS/Windows execution NOT RUN. |
| C | core/time-quota/astra6-parent-review.json:274/0, exit0, no skips/exclusions/source change | Reviewed CORE6 common admission/OWNER/Safety/MEM, concurrency/deadline/telemetry and lifecycle cases. Later typed CORE seam is active and needs review/reverification. |
| I/E | config/final-receipt.json:58 unit +37 component +12 corrected-protocol, all0 failures/exit0; entry/receipt.json:312/0 | Normalization, provider/Phoenix/Gateway/JSON, omission provenance and explicit-policy contracts; final integration still needed. Original failed invocation remains preserved. |
| H/HR | h1-h2/time-quota/receipt-final.json:340/0 +38/0 =378/0; final-review/receipt.json:DONE, zero frozen-input drift | Settled H1/H2 scoped implementation/source review. All15 candidate paths still match the frozen review; this audit does not repeat that code review. |
| HP/HF | qualification/parent-h1h2-final-compatibility.json:340/0, exit0; parent-h1h2-final-budget-helper.json:22/0 followed by helper16/1, exit2 | Fresh native HTTP passing scope is340+22; the latest helper is FAIL for persistent H3 SSE (`session_terminated`, :killed). Earlier helper16/0 is not current whole-source acceptance. |
| P3/P19 | qualification/parent-phoenix-mixed-{diagnostics,compatibility}.json:3/0 and19/0, exit0, stable inputs | Actual Phoenix adaptive mixed H1/TLS H2/H3; combined body/SSE/LiveView/WS/configured limits. Earlier3/1 retained. These do not accept later H3 lifetime edits. |
| Q2/Q3 | h3/time-quota/recovery3/{initial-network,native-lifetime-repair}.json:2/0 and3/0, exit0 | Provisional active-owner checkpoints only. No frozen H3 final review/acceptance; lifetime/SSE/WS compatibility remains pending. |
| K12/K7 | qualification/parent-{package-staging,built-consumers}.json:12 Python tests and7 ExUnit cases, exit0; three positive manual/production/release-isolation markers | Local rebuilt0.13.1 prequalification, not final selected-version publication-source or public-artifact evidence. |

The C/H receipts fingerprint broad contexts. Later CORE/H3 changes are expected
and recorded as later integration, not retroactive invalidity. Frozen H1/H2
candidate paths remain unchanged; its context references are not a current
whole-source freeze. Active H3/typed CORE and all shared BEAM state remain owned
by /root/budget_core_time_recovery. No new H3 correctness verdict is made here.

## Original12 Definition-of-Done items

SCOPED means the named deterministic/network assertions have terminal passing
evidence; every row still needs final frozen integration where relevant.

| DoD | Required outcome | Concrete tests and existing evidence | Remaining ordinary evidence |
| --- | --- | --- | --- |
| D1 | Default soft =50% reliable effective capacity | system_memory_test + resource_budget_policy_test: finite capacity selection/odd/overflow; Phoenix resource_budget_test public detection/threshold assertions. M/C/P3. | Native OS distinction below; final snapshot/gates. |
| D2 | Unknown capacity ->256MiB | Policy exact256/512MiB fallback, SystemMemory malformed/unavailable/native cases. M/C. | Final integrated pass. |
| D3 | No listener/instance multiplication | resource_budget_owner_test multiple instances/racing gates; resource_budget_phoenix_test independent ListenerSets; actual two-Endpoint and mixed3 cases. C/HP/P3. | Active CORE changes + final mixed qualification. |
| D4 | <=100% NORMAL | Policy100%/one-byte boundary and OWNER exact projected boundary. M/C. | Final integrated pass. |
| D5 | >100%..200% admits, rate-limited warnings | Policy200% boundary; OWNER warning telemetry/rate limiting/shared VM warning. C. | Final integrated observability gate. |
| D6 | >200% rejects new work atomically | OWNER racing reservations/projected hard overflow/shrink/recovery; Admission deadline/identity; protocol-local quota refusals in resource_budget_h1/h2/network H3. C/HP/HF/Q2. | H3 final qualification; final all-suite. |
| D7 | Strict protocol/OOM safety survives | Safety stale/missing/controller/process/headroom cases, OWNER sample races; H2 WorkerAccounting/HPACK pre-decode refusal, backing/read floor; H3 controlled byte metrics. C/HP/HF. | Active native seam and final protocol/source-built qualification. |
| D8 | Dynamic connection/request accounting | H1 independent connections/keep-alive/uploads; H2 retained decoder/no high-water/stream uploads; public Phoenix counts; H3 resource_budget_h3/network. HP/HF/P3/Q2. | H3 native ownership and final integration. |
| D9 | Completed work relinquishes ownership | CORE terminal-pair/guardian/spawn proof permutations; H1/H2 zero counters and peer-close cleanup; actual Phoenix zero usage/cleanup. C/HP/HF/P3. | G1 churn; H3 lifetime/SSE/WS and typed native proof final. |
| D10 | Phoenix H1/H2/H3 concurrency within capacity | examples/phoenix_native/test/resource_budget_test.exs: two TLS H2 connections +3 held streams and adaptive mixed H1/H2/H3; actual LiveView/WS combined cases. P3/P19. | Final actual independent Phoenix clients and active H3 qualification. |
| D11 | Explicit configuration/migration preserved | resource_budget_{config,activation,owner,admission}, provider/Phoenix config; explicit legacy transport/lease undoubled; H3 cap64 config. I/E/C/HP. | Final compatibility/package gates and reviewed migration docs. |
| D12 | Telemetry/tests/docs/release metadata truthful | OWNER numeric snapshots/reasons/rate limits, Admission category high waters; docs/resource-budget.md/design/plan; K12/K7 local package checks. | Active findings, G1, final docs/version alignment, review, commit/push/CI/release/public-readback all pending. |

Test names above are under apps/gaoxy/test/ unless prefixed by H1/H2/H3/Phoenix:
H1/H2 resource files are apps/gaoxy_http/test/resource_budget_{h1,h2}_test.exs;
H3 files are apps/gaoxy_http3/test/resource_budget_{h3,network}_test.exs;
actual Phoenix files are examples/phoenix_native/test/. HP includes the H1/H2
compatibility files; HF's first22 cases cover H1/H2 budget/defaultTLS/constructor
files. Exact command file lists remain in the cited receipts.

## Original20 verification requirements

| Verification | Concrete coverage / terminal evidence | Disposition and precise gap |
| --- | --- | --- |
| V1 Memory on supported platforms | system_memory_test injected Linux/macOS/Windows; system_memory_native_test supervised memsup probe/caller death; actual Linux Phoenix public detection. M/C/P3. | Deterministic/Linux scoped PASS. Real macOS and Windows execution NOT RUN; a Linux call to injected native labels or portable HTTP smoke is not native platform proof. |
| V2 256MiB fallback | Policy fallback and SystemMemory unavailable/malformed/unsupported cases. M/C. | SCOPED; final all-suite pending. |
| V3 50% calculation | Policy half/odd/max finite integer assertions and actual Phoenix public soft/hard detection checks. M/C/P3. | SCOPED. |
| V4 100% warning boundary | Policy exactly100 normal/one-byte-above warning; OWNER committed transition. M/C. | SCOPED. |
| V5 Admit100..200% | Policy/OWNER warning admissions and concurrent shared projected commits. M/C. | SCOPED. |
| V6 Refuse above200% | Policy exact200 warning/+1 over-limit; OWNER overflow rejection before mutation. M/C. | SCOPED; protocol H3 final pending. |
| V7 Release/recovery | OWNER shrink/release/re-admission; two-gate Admission reduction; H1 overload recovery and H2 expired-start same-connection slot reuse. C/HP/HF. | SCOPED H1/H2; native/H3 terminal completion pending. |
| V8 Independent H1 connections | resource_budget_h1_test: distinct held workers,2connections/2requests, keep-alive reuse and final public zero. HF22. | SCOPED PASS; final integrated repeat pending. |
| V9 Independent H2 connections | http2_default_concurrency_test + actual Phoenix adaptive TLS H2 case with distinct owners and reuse. HF22/P3. | SCOPED PASS; historical single-connection regression covered. |
| V10 Concurrent H2 streams | resource_budget_h2_test overlap/stream-local refusal/live sibling/HPACK continuity; actual Phoenix3 workers on2connections. HF22/P3. | SCOPED PASS. |
| V11 H3 concurrency | resource_budget_network_test2 independent aioquic peer:2 held streams, third0x107 refusal, live sibling/drain and public idle; mixed PhoenixH3. Q2/P3. | Active provisional checkpoints; final lifetime/SSE/WS/cleanup qualification OPEN. |
| V12 Phoenix LiveView/WS | websocket_phoenix_compatibility_test actual LiveView300KiB draft/reconnect plus channel close; websocket_default_capacity/configured cases; HTTP2WebSocket sibling. P19/HP. | Ordinary H1/H2 scoped PASS; final unified H1/H2/H3 client gate pending; H3 WS pending. |
| V13 SSE/streaming | Phoenix stream_lifetime_test later keepalives/finite route; native stream_lifetime_test/H2, poll_boundary and helper positive stream checks. P19/HP. | H1/H2 scoped PASS; latest helper16/1 is H3 SSE failure. H3 lifetime/SSE remains OPEN. |
| V14 Concurrent uploads | resource_budget_h1_test two partial uploads/2workers; resource_budget_h2_test overlapping body streams, exact echoes and membership lifetime. HF22. | SCOPED PASS; final all-suite pending. Phoenix body_test proves parsing, not an invented concurrent-upload count. |
| V15 Connection churn/cleanup | Individual H1/H2 connect/close/zero tests, keep-alive reuse, repeated H2 stream/generation and LiveView reconnect exist. | **G1 missing:** no identified finite same-instance repeated connection open/request/close/reopen test with public zero usage/counters/cleanup between rounds and passing receipt. Existing stream reuse is insufficient churn evidence. |
| V16 Cgroup limits | SystemMemory v1/v2 ancestors/hidden hierarchy/unlimited/permission/malformed/overflow and Safety current/high/headroom injection. M/C. | Deterministic scoped PASS; actual host/container metadata only as exercised by Linux runtime; no live limit mutation or real v1/v2 container matrix claimed. |
| V17 ListenerSets/instances | OWNER VM-shared atomic accounting, native independent ListenerSets and actual two Phoenix Endpoints/mixed3. C/HP/P3. | SCOPED PASS; active CORE/H3 final integration pending. |
| V18 Explicit/backward compatibility | Config/activation/provider tests; exact max_bytes/max_active/category caps and independent quotas; H3 options/backend cases. I/E/C/HP. | SCOPED; final all-suite/package/isolation compatibility pending. |
| V19 Crashes/cancel/drain | CORE DOWN+EXIT/authenticated guardian/proof retries, staged-activation ordering; H2 peer close with buffered unfinished siblings/final join, drain floor; H3 killed sibling/native-registration checkpoints. C/HP/HF/Q2/Q3. | H1/H2 scoped PASS; current typed CORE/H3 source review and final native/lifetime/SSE/WS OPEN. No forced-writer/slow-peer proof inferred. |
| V20 Warning telemetry/reasons | OWNER committed transition/log rate limit/shared VM warning/numeric snapshot, Safety-specific refusal reasons; Admission work status/high waters. C. | SCOPED deterministic PASS; final integration pending. |

## Actionable gap and remaining gates

G1 is an ordinary finite regression, not pressure/soak work. A bounded same-server
close/reopen sequence should assert successful independent HTTP transactions,
actual terminal ownership, public zero usage/connections/requests/streams and
cleanup_pending between rounds, then successful re-admission. Reuse current
clients/helpers and finite deadlines. No test/source was added or run here.
The parent has reserved a later bounded assignment; this audit grants no build
or source ownership transfer.

Known active work stays with its owner: typed native reserve/split/update and
native-engine terminal proof, H3 compatibility/lifetime/SSE/WS and the latest
helper failure. Partial2/0 and3/0 receipts must not replace frozen independent
review and fresh final protocol/CORE evidence. After source ownership returns,
reconcile all scopes, G1, active test counts and source hashes, then use the
existing release-preflight/gate-map.md recipes rather than a second command list:

1. Independent final scope/integrated review, then current manifest/inventory,
   formatter/strict compile and complete canonical all-suite with positive exact
   counts and zero failures/exclusions/skips. Preserve the historical816/16 and
   later failed receipts; no sum of old passing slices substitutes for this gate.
2. Actual Phoenix/unified independent clients and ordinary protocol integrations;
   package staging, clean built/source consumers, isolation and source-built
   standalone core/gateway/H3 smoke on the final selected/versioned source.
3. Parent selects unused version and publication SHA, aligns manifests/docs,
   commits/pushes current branch, confirms exact remote SHA and CI dispositions,
   then executes the guarded coordinated six-package/standalone release.
4. Fresh public Hex consumers, exact tag/GitHub8asset/7checksum/Hex6-byte/source
   read-back and actual downloaded executable qualification. Prepared offline
   verifier controls are not public artifact/runtime acceptance.

Native macOS/Windows memory execution remains explicitly NOT RUN. Keep that
coverage limit separate from Linux passing evidence. Browser automation,
pressure/slow-peer/sustained-load/forced-writer expansion, #97, production data,
operational certificates, Vault/public-management and deployment remain outside
this audit. No new product design decision or authorization is requested.
