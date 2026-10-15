# Native TLS ownership — independent SPEC and focused code-contract review

**SOURCE_APPROVED_FOR_VALIDATION; TEST_COMPLETION_REQUIRED.** Ownership/API repair is coherent and causally supported by actual diagnostic. One targeted authoritative-owner-deadline test gap remains before final acceptance; no production-source defect identified.

Repository `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`, branch `codex/m3-h1-resource-foundation`, historical baseline `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. Proposal reviewed in memory, not applied. Root owns actual source/runtime/evidence/Git; only these new /tmp reports written.

## Actionable validation finding

**TLS-SPEC-01 P2** — Transport.operation returns {:error,:timeout} immediately for locally expired Exchange and does not call owner. Both proposed live cases exercise only this local expiry. New owner-side deadline guard is therefore source-inspected but not exercised.

Complete the author-listed targeted finite unit or deterministic live check that reaches owner :ssl_data with authentic call authority or explicitly scoped owner-handler unit fixtures, local deadline still future while authoritative stream deadline expired; assert timeout/no full data. Do not disable watchdog or invent a positive runtime authority/receipt.

No source production bug found; proposed ownership repair can be adopted for validation. Final SPEC acceptance remains pending test completion and actual gates.

## Requirement/source map

| ID | Verdict | Evidence |
|---|---|---|
| T01 | PASS_SOURCE | Proposal md/json/patch hashes match; four original/after hunk reconstructions and all12 source-input hashes independently authenticated. |
| T02 | PASS_DIAGNOSTIC_ONLY | Actual diagnostic2 capture hash authenticated: same original pump rejected; changing only ssl:nil admitted. Owner has same SSL/gate, securetrue,38 actual entries incl session_data2281/functions. Inner exit1 remains FAIL, not acceptance. |
| T03 | PASS_SOURCE | Connection.handle_connection already obtains complete Socket.connection_information into owner state.ssl; existing connection Admission lease is acquired before native H2 handling. Proposal retains original state.ssl and connection reserve. |
| T04 | PASS_SOURCE | Only nativeH2 Exchange constructor changes ssl:state.ssl to ssl:nil; group pump no longer receives that duplicate root. Accountant finite grammar, role caps, whitelist, projections and existing negative assertions unchanged. |
| T05 | PASS_SOURCE | Exchange.ssl_data nativeH2 clause precedes generic transport clause; actual worker uses supported existing Transport.operation(:ssl_data), returns complete original data or nil on closed/timeout. Plug adapter delegates directly, preserving live worker API data. |
| T06 | PASS_SOURCE | Native owner call/4 authenticates exact stream ID/token and actual From PID==stream.worker before invoking operation; wrong stream/token/foreign copied capability receives closed; no new process/global authority or runtime query inside pure accountant. |
| T07 | PASS_SOURCE | Transport operation uses local absolute request deadline and finite call timeout; new owner checks authoritative stream.deadline independently and replies timeout on expiry. Owner handler does not call itself; current SSL API callsites run inside worker/Plug endpoint. |
| T08 | FINDING_TEST_GAP | Proposed local expired Exchange is rejected by Transport.remaining before owner call, so it never proves new authoritative stream.deadline guard against extended local deadline. Proposal explicitly requires additional bounded unit/live verification; missing from its3 new tests. |
| T09 | PASS_SOURCE | H1 direct secure Socket path and H3/other stored metadata clause unchanged. peer_cert/secure/peer/local unchanged. Foreign copied Exchange getter intentionally changes to nil and is documented; valid live worker returns original full value. |
| T10 | PASS_SOURCE | Actual nativeTLS tests generate local fixtures, verify peer CA/name and ALPNh2, exercise both real upstream TLSH2/h2c; assert owner.ssl==Exchange SSL==Plug SSL and nonzero actual session_data, Exchange.ssl=nil, real native owner/request leases. |
| T11 | PASS_SOURCE | Wrong stream, wrong token, foreign real copied token and expired local operation exact errors tested. Foreign public getter nil, with original worker request held behind finite observer monitor/deadline before GroupEndpoint. |
| T12 | PASS_SOURCE | Real GroupEndpoint request requires exact empty-query target, original RequestCompletion in G/Session, Service cleanup full16478862 on genuine request lease and correct token->Service guardian, actual200/bodyempty and original completion await. |
| T13 | PASS_SOURCE | Native connection/writer/worker monitors join; service retained/active/cleanup totals zero, nil cleanup failure and highwater bound, explicit nativeTLS service removal then exact existing G/T baseline cleanup and peer termination. No fake success/receipt. |
| T14 | PASS_SOURCE | Response reader has finite frame count256, frame cap16384, body cap65536, absolute finite receive deadline and settings ACK. Empty200 target avoids continuation/upload ambiguity; original RequestCompletion await finite5000. |
| T15 | PASS_SOURCE | Pure accountant new case admits nativeH2 nil TLS shape structurally only and keeps rejecting session_data, PID, improper lists, logical65537 and128-visible-byte subbinary backed65537; grants no live runtime authority. |
| T16 | PASS_SOURCE | New test alias HTTP.RequestCompletion resolves public HTTP module, no Proxy.HTTP alias collision. Test actual owner state correctly unwraps {socket,native}; source patterns inspected but not compiler-accepted evidence. |
| T17 | PASS_SOURCE_LIMITATION | Explicit endpoint SSL API return still copies full metadata to caller under existing API; production group pump does not call/store that return. Existing connection lease unchanged; proposal establishes no new complete arbitrary OTP connection memory bound. |
| T18 | PASS_SOURCE_PENDING_RUNTIME | Scope is necessary native transport compatibility, no cap weakening. Adoption may proceed after review; final acceptance requires targeted authoritative-deadline check, actual format/compile/tests, fresh live/Session/nativeH1/H2/H3 compatibility and browser3. |

## Identity/evidence

Proposal MD SHA `e9544f98b492cd1ac670f822703eb1b51df270b96aedf667fd27699abc8c72cf`; JSON `545e55d8236ed40079b5fab3155f60cb322a009c0446831e63cca47fb458b49b`; patch `3821eae059f8b03d01eb20726ce536ee4fcc8c4e05494a4ec72a71314f609d79`. All4 target reconstructions and12 supporting hashes match. Current postadoption workspace is not described as still matching historical175 manifest.

- `apps/gaoxy_http/lib/gaoxy/http/exchange.ex` before `9e0c90640fb057108e3dcd174b56186e8194f8f06bf946cdf03bcc68ac12bf71`; proposed after before formatter `513c300e4b3a161d54465696663eaa024acc7061c87aa43f961c42ea54de5652`.
- `apps/gaoxy_http/lib/gaoxy/http/http2/connection.ex` before `7327d4e1fe79676efdb6ad973389a6d4e78adb8d3f1fecb747f8c180b40e2584`; proposed after before formatter `5696219cf250cada82badd531d1f28869b3a4145b78dc7ec43af956d7f765400`.
- `apps/gaoxy_proxy/test/managed_h2_group_accounting_test.exs` before `8ec0d0568ba2d9180be33dc421f7294a5fe8ec6988002d5c64b6c7fe48ec2eb8`; proposed after before formatter `300e315d2d37ee927fe6eb2b7c1f210183ce83ec11aa118fc7059f8b87d586a1`.
- `apps/gaoxy_proxy/test/managed_h2_group_native_tls_ownership_test.exs` before `None`; proposed after before formatter `bee3be78b40e51154bf6cf6ccd1d65ab498d77d98a0e46de18e1509bdf3e664c`.

Diagnostic2 receipt SHA `1ff747a4b741b95d33c8563e668f13429e64b03955b7a71efbeac3094445c398`; capture SHA `0f6f05ca2b4a8f9bf66f020339fb3d3727aa96869790a2c4de4b8e09915eb07f`. Actual VMroot `/nix/store/vp5phkfsvnldrznkzy0qkcgm8fi0pdc5-erlang-28.5.0.7/lib/erlang`; capture explicitly acceptance=false. Inner exit1 and0completed browser cases remain failure; diagnostic wrapper expected-failure capture success is separate. Earlier collector failure remains historical, not repaired acceptance.

Reviewer tests/runtime/build/compile/formatter/browser/Git NOT RUN. Read-only Python reconstruction/hashes PASS. Proposed count3 new tests, executed0. Original assertions/caps preserved. All own commands completed, no processes launched/touched.

Reviewer repair rounds0; parent reported failedGREEN18/root event20 at assignment; preserve latest parent ledger and all inherited counters, Astra2/2 exhausted. No new external permission/product decision required. Publication/deployment/production/Vault/operational cert/public management/release-artifact E2E restrictions remain.
