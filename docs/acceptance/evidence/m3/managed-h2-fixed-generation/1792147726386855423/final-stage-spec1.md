# Complete fixed prepared-T upstream H2 Generation — independent SPEC review

**DONE — full-stage SPEC review PASS. No remaining actionable findings. This is not stage acceptance.**

Task `/root/fixed_generation_final_spec1`; direct independent read-only assignment. Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline HEAD `aa272c3dca700a9275a00bd23920d09bbd4748a1`.

## Frozen candidate

Evidence root E2: `docs/acceptance/evidence/m3/managed-h2-fixed-generation/1792147726386855423/`.

| Identity | SHA256 / verification |
| --- | --- |
| Initial `final-stage-candidate1.json` | `767e93b77272a0e986f651cb772f604f7ea04ee9a1c123742fc90e3c2b6f935e`; 397 sources /160 evidence entries |
| **Reviewed final `final-stage-candidate2.json`** | **`fefe810460bf1733e3077db8b6574832ab2b4ef723e2556adfc4560febd7f42b`**; 397 sources /164 evidence entries |
| Host2 | `3a543ae6cf85f26dfe593d3d474f8a7370b8b6ad8e2e07a3e57da5806ec564d9` |
| Runner2 | `ecdeec87aeaa9d2026375a950923d29bb1449e87ef9e55ed325ea1ef9b8f8f94` |
| Metadata-copy receipt | `7c3a5a2702e37d9e4ba697a141037ed947d1f0c55f0df6f75b92ecfcf05b3291` |

Every source/evidence hash matches the actual file, before and after the additive replacement. All397 sources and original160 evidence entries remain unchanged. Candidate2 adds only candidate1 itself, host2, runner2 and `browser-fixture-metadata-copy2.json`. Source paths resolve against the worktree; evidence paths against E2.

## Coverage and findings

Reviewed complete matching design, plan and acceptance; full production/test/roadmap diff; full new1685-line test and exclusion test; actual Generation/Store/Resources/Router/ProxyHTTP/Session/owner/native/accounting/Service/Admission paths; complete browser host/runner/cohort/collector; exact candidate2 deltas; archived browser reviews; initial failure and GREEN3–6 evidence; actual browser qualification, loaded inventories, peer/image receipts; late observer receipts; generic sidecar consistency coverage.

| Specification area | Concrete source/evidence | Conclusion |
| --- | --- | --- |
| Pure canonical boundary | `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex:242`; `managed_h2_envelope.ex:80,312,330,463`; exclusion test | Sole production change reuses existing pure `ManagedH2Envelope.validate_config`; invalid config retains exact `:unsupported_generation_endpoint`. Complete8-field shape, explicit client/protocol/scheme, T4, canonical compact URI/limits and no direct trust/address remain required. Shape is not live identity. Sixteen malformed exclusions, missing-sidecar error and H1 contract remain. |
| Checked admission and immutable capture | `generation.ex:133,269,308,443,517,690`; `resources.ex:75`; `router.ex:43,98` | B charged in original native lease before effects; original acquisition ledger authenticates operation/acquirer/holder. Serialized Store captures current exact router/pins, passes original Exchange and dispatches captured endpoint. Rollback cancels original operations. |
| CAS/initial compiled consistency | Same Generation/Router paths; new test `:230,1445,1484`; generic sidecar test | Compiled route/sidecar validation precedes baseline acquisition; CAS atomically replaces router/baseline then retires old baseline. Prepare/public/direct/initial routes/router consistency remains. Genuine stale epoch/nonexistent T4 fails baseline acquisition; immutable binding catches genuine mismatched T4 later. Snapshots remain unchanged on refusal. |
| Standalone and one-use authentic child | `http.ex:282,590,939,1122`; `upstream_transports.ex:348,399,1011,1034`; test `:500,1170,1301,1416` | Empty pins intentionally remain standalone. Nonempty selected-pin/holder/ref failures never reacquire. Authentic source equality, original deadline/op/epoch, protocol/authority/instance and distinct Session holder authenticate one-use child. Original native T8 and original completion are retained. Delegate/checkout/bind/finish exactly once; no outer repin. |
| Captured right survives closed admission | `upstream_transports.ex:889,1011,1034`; test `:90,304,1267` | Ordinary fresh acquisition requires open admission. Authentic captured delegation/checkout survives CAS, configured holds gone and Store death. Fresh request after Store death fails500 with exact zero owner effects. |
| Original completion and real joins | `session.ex:1201,1347,1400,1626,1683,1711,1762`; test `:1301,1363,1404,1620` | Real Service attachment precedes activation/delegation; original public completion bound before ready. Public cleanup precedes token finish, child release, receipt and normal Session stop. Native joins actual Session DOWN before return. Source/native remain until their original terminal barriers. Successful terminal checks include Gate0/cleanup0, normal Store/owner/custodian/instance joins, all-zero owner, peer exit0 and exact rebind. |
| Retirement and sticky failure | `upstream_transports.ex:1102,1117,1151,1522,1608`; test `:734,794,853`; `service.ex:130,599`; `admission.ex:409` | Source/child/token holds keep resource alive after ordinary admission closes. Final physical cleanup/join precedes settlement. First failed retirement stays failed. Late stop retains `{:error,{:deadline_exceeded,:cleanup_pending}}`; original force input is one lease/one cleanup with authentic positive bytes then actual Gate:killed, never Gate0. Separate original completion join and actual Service terminate `:normal,:stopped,cleanup0,failednil,drainnil` do not erase the failed receipt. Compact observer retains no raw state argument. |
| Real protocol/negative matrix | New test `:14,58,90,230,254,304,368,427,500,1283` | Six real prepared-T positives, initialized callback/original Exchange wrapper and four actual H1/H2 × h2c/TLS-H2 socket cells. Exact target/authority, h2 ALPN/localhost SNI and peer/port/connection/stream correlate. Stale CAS, abandonment, actual coordinator/Store death, cancellation and forged/missing/wrong-holder/mismatched identities retain exact errors and no-effect assertions. Cancellation502 differs correctly from genuine endpoint mismatch503. |
| Accounting invariants | `managed_h2_reservation.ex:17`; group accounting`:78`; Generation accounting`:75`; worker accounting`:12,64,99,372`; H2 connection`:545,1191` | No charged constructor/lifetime/multiplicity changes. Fixed9,444,956; group16,478,862/startup5,963,776; H/Q65,536; unchanged T4/T8/B and native95 P/N/W. Original endpoint/Exchange measured; actual W charged before worker spawn; original lease/protocol/deadline retained. No physical-memory-bound claim. |
| Predecessor accounting preservation | E1 `native-worker-accounting/1792113258488285300`; E2 Cohort1/host/runner | Whole Cohort1 equals predecessor cohort3 (`86776f89816c8659b01d2b3e32133dc6af06eb1d212a4d26bd07993af81c2d8c`). Correct extraction boundaries prove equal arithmetic, independent B/native methods, reserves/cohort/terminals and Actor/adopted custody (`28baecf41dc6012b75ca3dad30decad5feead9eda7142bd8a57d4bc5b91ca34f`). Initial broad extraction included adjacent helpers; corrected comparison resolved it without runtime repair. |
| Browser lifecycle and evidence | Host2 executable-equivalent host1`:335,409,443,455,495,525,578,610,802,947,1024,1155,1189,1242,1267,1340,1409,1465,1666,1760`; runner2/collector1 | Genuine preparation/source/child/completion/CAS/custodian/native ordering; actual whole-cohort Gate cut, original monitors, independent B/native95 and real joins. Four mandatory CDP rows assert old/new Document status200, URL/title/text/raw target/protocol/TLS/visible bounds, silent console/exceptions and screenshots. Browser.close, Chrome exit0/no signal/profile removal, owned Actor normal joins, separate adopted waits, recursive subreaper custody and finite600s collector are mandatory. Serial browser makes no overlap claim; sockets cover overlap. |
| Documents and scope | Matching design/plan/acceptance and roadmap diff | One prepared fixed T4, upstream h2c/TLS-http2, native H1/H2. Tasks0–5 initially implemented/verified; Tasks6/7 correctly pending. Group Generation, full streaming, trust/IP rotation, H2 twenty reloads, standalone/load, H3 accounting and whole Task5/M3 remain unaccepted. |

**Resolved finding:** runner1 line531 and initial browser qualification labeled the literal `group43/root58/Astra2of2; successor failedGREEN2/fixtureRepair1/orchestrationRepair1; browser runtime gate` as `entry_counters`. Candidate2 renames it `fixture_development_cutoff`, preserving historical values and original evidence. Host2 fixes two stale source-only comments; runner2 fixes its stale docstring and selects host2. Exact deltas change no predicates, timeouts, browser/network/accounting/cleanup/Actors/CDP mechanics; Cohort1 is unchanged. Fresh browser must use runner2/host2. No open actionable finding remains.

## Initial evidence, not final gates

The reviewer audited these archived results without running runtime commands:

| Run | Actual result / disposition |
| --- | --- |
| RED1 | 6 executed /6 intentional unsupported failures /38 excluded /0 skipped, exit2; joined/stable. Explicit audit corrects collector total44. |
| boundaryGREEN1 | 47/0, exit0; **nonaccepted unstable-source FAIL**, overlapping formatter preserved. |
| GREEN2 | Compile FAIL,0 executed, exit1. |
| GREEN3 | 57/0, exit0, stable/joined. |
| GREEN4 | 83/8, exit2, FAIL preserved:6 wrong draft502 expectations corrected to source-required503 with exact mismatch errors retained;2 cancellation-order repairs preserve original assertions. |
| GREEN5 | 83/0, exit0, no skips/exclusions/warnings, nonforced/stable/joined/group empty. |
| GREEN6 | 83/0, same clean metadata; real additive Gate/Service observer executed; complete log read. |
| BrowserGREEN1 | 4/4 PASS,8 images; collector exit0/nonforced/joined/group absent/no descendants/timeoutfalse/stable. Root image-view receipt/hash checked; reviewer did not personally view images. |

Browser audit:16 owned Actors exit0/nonforced/readers joined/groups absent;22 separate adopted waits =18 exit0 +4 exit-10(signal10), none remaining. All4 loaded-before/after inventories match (102 entries each) and actual source hashes match current. Each old/new peer has one accept/one request, forced0/live0/failedfalse and physical connection_reset before stop. Each row records Service active0/retained0/cleanup0/failednil, genuine joins/rebind. H2 W219228/B11248838/native95 and H1 retained1308/B11248838 remain actual measurements. Unique peer identities disambiguate conn1/stream1. Artifact/image hashes match.

Current test differs from GREEN6 only in comments: reversing the two factual comments to the four original comments yields exact GREEN6 SHA `bf7495748c5414f4893a9848a257546de890e287d5adedc3e930407ebeda3950`; candidate SHA is `7eb73bc20c2c362e1b314e9cde16370defa78946ca32e5a00100b10938367b3e`. Original text is preserved in `failures-green5-input.exs:166`. Additive root `post-green6-comment-delta1.json` accurately records reconstruction, not an originally captured snapshot or new runtime. It is outside candidate2 inventory and marks fresh execution PENDING. No executable delta; fresh exact gates remain required.

## Ownership, checks and handoff

Existing task diff is root-owned: narrow ProxyHTTP guard, exclusion/new tests, matching documents/evidence and roadmap updates. Reviewer changed only the two assigned `/tmp/gaoxy-fixed-generation-final-spec1.{md,json}` reports. No public interface/dependency/process design or unrelated cleanup was introduced by this review.

Read-only file/diff/identity and Python hash/data checks completed successfully. Final hash iteration checks every source/evidence entry in both candidates with zero mismatches, all397 sources equal and all original160 evidence hashes preserved. Protected worktree `codex-prompt.md` remains SHA `87112f8eb621966e0062c8611054bda49af0508693c46fa621de87a2b774038c`; main-root `gaoxy-m1.1-fix-prompt.md` remains `7982874aacafe8bc4f4814740f25d1bd1e5bb35cbdc3938338ab132f2cdf9f1f`.

Inherited counters unchanged: group failedGREEN44; root events60; Astra2/2 exhausted; stage failedGREEN3; fixtureRepair3; productionRepair0; orchestrationRepair2. Reviewer adds0 Sol repairs,0 Astra rounds,0 failed GREEN; `astra_gate=null`.

Pending root gates: complete independent CODE; fresh exact19-file union through three documented unfiltered commands; strict forced compile; changed-source/evidence Elixir format; Python/embedded syntax; isolated core/HTTP consumers; fresh four-row runner2/host2 browser and root viewing8 images; final docs/custody audit; authorized local conventional commit. These are NOT RUN/PENDING, not failed/blocked or passing here.

No tests/build/browser/application/listener/network probe/agent/Git mutation was started by reviewer. All commands returned; no reviewer background process exists; root retains exclusive runtime/repository/Git ownership. Prohibited raw terminal trace and other reviewers' in-progress reports were not read. No new user/design decision is required. No whole-stage/Task5/M3/M4, hosted CI, publication, deployment or production acceptance inferred; no Vault/production data/certificates/public-management/disabled-E2E expansion; dismissed `gsmlg-dev/http_fetch#97` not revived.
