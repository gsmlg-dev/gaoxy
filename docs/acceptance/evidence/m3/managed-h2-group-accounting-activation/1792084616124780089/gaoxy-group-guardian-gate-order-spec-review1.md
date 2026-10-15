# Guardian gate ordering — independent SPEC review 1

Task: `E4/guardian_gate_order1/spec`. **DONE — SOURCE_ONLY_SPEC_PASS**.
Direct bounded source-only independent review, not runtime acceptance.
R: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Baseline supplied/previously read-only verified in this reviewer turn:
`codex/m3-h1-resource-foundation` at `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`.
Root owns the dirty repository, all source edits/build/runtime/Git. Only this
reviewer's two NEW /tmp reports are written.

## Verdict

**12/12 source requirements pass; no actionable findings.** The correction
preserves the original exact final pins1 assertion and adds a separately
observable pins2 phase while the genuine pump is prevented from returning by
this test's held Admission gate. This is a synchronization correction, not a
production repair or a relaxed cleanup criterion.

The real diagnostic supports the hypothesis, without proving this unexecuted
repair passes: both protocols show Gtokens0, Ttokens0/helpers0/pins2, and the
remaining nonderived request-pin holder is alive waiting in gen.do_call/4.
The added real caller/lease gate-message observation is the necessary direct
runtime check that the proposed correction still must execute.

## Checklist

- **G01 PASS (source):** Original G/T completion and Service full reserve are still captured/asserted before kill; four actual DOWN barriers and exact killed guardian remain.
- **G02 PASS (source):** Pump is the genuine Session state.owner; HTTP.start builds owner:self(), tying it to the actual HTTP caller rather than a substitute actor.
- **G03 PASS (source):** Lease comes from the original Service cleanup token in Admission cleanups; attach_cleanup records the genuine original request lease there.
- **G04 PASS (source):** Selected source is the sole real T request-kind pin with holder === original pump and exact original handle; no new capability is constructed.
- **G05 PASS (source):** Intermediate recovery requires exact Gtokens0 and Ttokens0/helpers0/pins2, while exact original G pins and captured nonderived source public pin remain.
- **G06 PASS (source):** Mailbox barrier observes actual synchronous $gen_call from the same pump and original lease with exact update operation; no fabricated reply or state mutation.
- **G07 PASS (source):** HTTP guardian DOWN calls fail→error_response→HTTP1.Response.send_resp→send_head→Exchange.send_bytes/send_chunks→Admission.update. This blocks source cleanup until the deliberately held gate is released.
- **G08 PASS (source):** GroupEndpoint.call pins source resources and releases in after only after HTTP.call returns for this direct endpoint fixture; the new ordering preserves legitimate live source ownership.
- **G09 PASS (source):** Gate release occurs while Service DOWN handler remains held. Admission guardian DOWN cannot manufacture a Service receipt; Service cleanup_down still records cleanup_receipt_missing.
- **G10 PASS (source):** Exact original final Gtokens0/Ttokens0/helpers0/pins1 predicate is retained after gate release; no weakening to pins2 or allowed-value set.
- **G11 PASS (source):** No Service receipt assertions, exact public failed shutdown reason, original completion confirmation, embedding/owner/peer joins all remain.
- **G12 PASS (source):** Only the bounded guardian case ordering plus temporary diagnostic removal changes. Two protocols and existing four templates/eight generated group failure tests remain; finite deadlines unchanged.

## Authentication and validation evidence

Patch SHA256 `e04363b3352192e443cc042b11664b58a2f54de3afff8cac746a3d9a395acaed`;
proposal JSON SHA256 `08793f01bd3325d3152bd35d2b247925c661772a878c56277e05c78c8990ed2f`.
Read-only Python in-memory unified-patch reconstruction verified every original
hunk and returned exit0: predecessor
`b4f044d48daaa16aaa3b1306556b52b70cc0083eb10c0334c4c33e6100a0c9dc`,
expected result before formatting
`703407e1ff6e633a6207cc4c1d52573dee0886c07d0f4678fd467a9e19983417`.
It separately asserted retained pins1 count, gate-release < finalpins1 <
Service-release ordering, removed temporary diagnostic function, unchanged test
template count4. Source reads and sha256sum completed.

Provenance correction retained explicitly: `7665dd82a277f340bcdb94c66bb25e5ab060aee7a2c6ce7c30be8f1f91f55181`
is the diagnostic **JSON command receipt** SHA256, not its log SHA256. The bound
actual log SHA256 is
`d87bb15c6d90c792868a57ac1b46822cea98912224abc48c129ea205b29918e9`.
Both independently matched disk and the receipt binds that log. Historical actual
48 tests/2 failures, exit2, joined/stable remains FAIL. It is not passing evidence
for this patch. Root confirmed the receipt/log distinction while this review ran.

Source identities:

- `apps/gaoxy_proxy/test/managed_h2_group_failure_test.exs`: `b4f044d48daaa16aaa3b1306556b52b70cc0083eb10c0334c4c33e6100a0c9dc`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/group_endpoint.ex`: `cf78f0bbb37bf76c0f4d9cad9b5d5843ce0f8457120f730591ba686b42459659`
- `apps/gaoxy_proxy/lib/gaoxy/proxy/http.ex`: `72f70becc478fe0e864015c033bcb1fec5f6aa51a8639cc9b35a0173191b6738`
- `apps/gaoxy_http/lib/gaoxy/http/http1/response.ex`: `dbf43ff0ee063758125093505749c8941fe2d4bda7f4d6b9429fe907f19cca85`
- `apps/gaoxy_http/lib/gaoxy/http/exchange.ex`: `9e0c90640fb057108e3dcd174b56186e8194f8f06bf946cdf03bcc68ac12bf71`
- `apps/gaoxy/lib/gaoxy/admission.ex`: `169f311b2a4995b3de901ac41b5c2768208c8f8c3e26d2e57a58fdefdc013a75`
- `apps/gaoxy/lib/gaoxy/service.ex`: `740d69a364e52cda9d05a997136ce864e9ec464149adcc81045bc9c109ed4472`
- `apps/gaoxy_proxy/test/support/managed_h2_group_fixture.exs`: `4d5f70dcee198409fb481947ddfb24e9d65dc65b3b41c0a58e8f6627778b1c53`

One exploratory source search used absent gaoxy_core/gaoxy_http1 directories and
returned exit2 missing-directory diagnostics. Subsequent scoped apps search
located actual gaoxy and gaoxy_http sources. No test/build check failed or ran.

## Limits and shutdown

Runtime/formatter/compiler/browser/Git: **NOT RUN**. All own commands finished;
no application actors started, signalled, stopped or joined. Repository writes0.
Reviewer repair rounds0; inherited Sol/root counters unchanged and parent-owned;
Astra2/2 exhausted, no third round requested. Root must integrate, format,
compile and run the fresh prescribed scoped gates. Runtime ordering remains the
material unverified risk. No external permission or product decision needed.
