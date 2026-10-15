# Bounded SPEC review — startup overlap and observer repairs

**PASS_SOURCE; runtime pending.** The three frozen proposal patches source-resolve FULL SPEC findings SPEC-01 and SPEC-02 and preserve the recovery barrier while removing redundant continuation noise. No actionable source findings.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Candidate175 remains unmodified. Patches reviewed through exact in-memory reconstruction, not applied to checkout. Metadata SHA256 `116312c81f9526be4c3143cecbfc14945284b8500006faa57d22ad79137a0cd0`.

| Check | Verdict | Evidence |
|---|---|---|
| R01 | PASS_SOURCE | Three patch SHA256 values, original target hashes and exact in-memory reconstruction after hashes match metadata; no checkout application. |
| R02 | PASS_SOURCE | SPEC-01 requirement plan126-129/design207-219: positive template expands to all4 nativeH1/H2 x TLSH2/h2c cells with healthy genuine initial Probe; no fake client or bypass. |
| R03 | PASS_SOURCE | ObservedEndpoint captures actual endpoint pump, actual original lease and genuine Admission state before HTTP startup; no synthetic lease/root. |
| R04 | PASS_SOURCE | Keyed sys.install {debug_id,debug,%{pending:nil}} is public supported API; map state prevents nested2tuple keyed-entry ambiguity. Callback never edits application state/results. |
| R05 | PASS_SOURCE | Exact OTP28.5.0.5 gen_server.reply emits {:out,Reply,From,NState} after genuine reply. Callback matches stored authentic From and :ok; fourth event element is actual postcallback Admission application state. |
| R06 | PASS_SOURCE | Admission.adjust_bytes authenticates original pump lease and adds startup5963776; test requires exact own lease delta and exact total state delta with no cleanup. |
| R07 | PASS_SOURCE | Admission.attach_cleanup requires actual Service, pump owner active lease and genuine guardian/token. Test matches Service From, sole cleanup token, original lease, receipt=false, full16478862 and unchanged startup lease. |
| R08 | PASS_SOURCE | Successful attachment actual total is before.bytes+5963776+16478862; highwater bounds enforced against genuine Service cap. before.bytes includes separately existing nativeH2 connection/writer/request leases; no mislabelling of ordinary payload. |
| R09 | PASS_SOURCE | Refund barrier holds actual incoming authenticated -startup call before application callback changes state. Finite5s receive and exact caller monitor provide bounded unblock; no synchronous gate call is made while gate held. |
| R10 | PASS_SOURCE | trace_delivered(:all) barrier flushes actual call/return traces before events snapshot. Same pump traces require successful helper return containing original guardian before exact refund call, actual Service attach caller/arguments and single real child. |
| R11 | PASS_SOURCE | Refund release then actual :out asserts exact original lease bytes restored, exact unchanged genuine cleanup record and total before.bytes+16478862; duplicate refund output refused. |
| R12 | PASS_SOURCE | Real upstream request target includes empty query. G/T-held selection matches original guardian/completion; actual Session original_request.completion matches; full Service hold asserted, actual peer200 and original completion await then exact clean/join fixtures. |
| R13 | PASS_SOURCE | Final flush after real clean/close verifies only +startup/-startup across complete trace. Existing eight denial cases are byte-identical; only common trace pattern list extraction changes helpers. |
| R14 | PASS_SOURCE | SPEC-02 patch changes stored observer state only to tagged arity3 {:delegation,from,operation}; exact actual From/operation/raw capacity reply matching and :done lifecycle retained, avoids sys.erl876 keyed2tuple clause. |
| R15 | PASS_SOURCE | Raw observer normalized invalid_resource_pin, exact502, original ledgers/sibling/refunds/no replay and native partial-DATA cases are unchanged. |
| R16 | PASS_SOURCE | Recovery barrier patch monitors actual parent and receives only exact continuation or exact parent DOWN, with original finite deadline; demonitor flush in after. Successful live release remains test211 followed by actual PID and debug remove213. |
| R17 | PASS_SOURCE | Removed unconditional on_exit recovery continuation cannot reach DynamicSupervisor after successful callback removal. On test death actual monitor unblocks held callback; remaining on_exit removes observer. Other real recovery assertions and finite synchronization unchanged. |
| R18 | PASS_SOURCE | Elixir alias Elixir.HTTP.RequestCompletion avoids local Proxy.HTTP collision; pinned guardian/pump/lease patterns, map fields and trace capture inspected for syntax and ownership coherence. Compile/formatter not run. |
| R19 | PASS_SOURCE | Positive Gate after/on_exit release is harmless to original Gate catchall and normally Gate is joined by G.close; trace flags/patterns restored in after; no new unbounded wait or fake receipt. |
| R20 | PASS_SOURCE | Full SPEC source findings01/02 closed by proposed code only; acceptance remains conditional on adoption, format/strict compile, fresh startup50 (expected) and live110/Session46 plus all prescribed gates/browser and independentCODE. |

## Patch identity

- `/tmp/gaoxy-group-positive-startup1.patch` SHA256 `ed8257558ed40a6abcd69e1f004b99d0cd7ce225e5b42da56b0e032c4ce14ee4`; target `apps/gaoxy_proxy/test/managed_h2_group_startup_reservation_test.exs`, original `af5730f75b2217d6bff5052434ce13fb24eaecdc7d1a3f0bf2fe551dc7582045`, reconstructed before formatter `ef0c18f261731b7e7120e9e56424737116774c05590ce986e48e7c173a4fdd23`.
- `/tmp/gaoxy-group-handoff-debug-state2.patch` SHA256 `1d56547371d3f57236f2ec82172f80181a2a12425c60f9a4c7a85a60f12234bd`; target `apps/gaoxy_proxy/test/managed_h2_group_live_gap_test.exs`, original `c907608a276f66cf3550407369eee31b4ed97597073474c616a8bde2dcb1752e`, reconstructed before formatter `e0b4cbedf8b60e85626b3d57a1ab6bb76af9e666385605bcd86df4a58451c543`.
- `/tmp/gaoxy-group-recovery-observer-cleanup1.patch` SHA256 `b3e785084468801078d82b53e04c6d8847d242af65d82afabb10e9f163542dd1`; target `apps/gaoxy_proxy/test/managed_h2_group_accounting_owner_activation_test.exs`, original `0dff9a288f929b8679e9cc264884b31fd8041dab4b3d6369a800757d0ce5c244`, reconstructed before formatter `3c7550eb75f941ede344251630d519d0db05d71482f84db7df632d7e5dd78e70`.

## Verification boundary

Read-only Python PASS: all3 patch identities, original target identities, exact reconstruction after identities, and original denial-test bodies byte-identical. Production Admission/Service and exact OTP gen_server/sys source read. No tests/runtime/build/formatter/Git commands executed; no actors launched or touched; only assigned new /tmp reports written.

Expected scoped startup total changes46 to50 due to4 new cells; this is a source-derived expected count, not an executed result. Parent must adopt and run fresh validation with exact source/count/exit evidence. FULL stage remains ENABLED_PENDING_ACCEPTANCE; authenticated110/2 FAIL and older failures/reports remain immutable. Negative browser cleanup retains UNCONFIRMED_WITH_RETAINED_FAILURE.

Reviewer repair rounds0; parent counters remain failedGREEN16, adopted ordered repairs16 at frozen candidate, Astra2/2 exhausted; patch adoption/validation may advance parent counters. No reset, third Astra or invented combined counter. No decisions needed. All own commands finished.
