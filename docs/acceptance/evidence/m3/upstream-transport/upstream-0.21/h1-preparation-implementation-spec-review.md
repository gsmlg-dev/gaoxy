# Managed H1 preparation implementation specification review

Task: `m3_managed_contract_review`, direct independent Sol **specification-only**
review, 2026-10-11 Asia/Shanghai. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. This reviewer authored none of the
implementation. Own only this new report; executable files and shared documents
were read without mutation, and other writers' edits/processes were preserved.

## Verdict and boundary

**PASS for specification conformance of the current formatted four-file pure
implementation.** No executable specification blocker was found against the
approved design/plan and prior design-only specification review. This permits
the parent to arrange the separately assigned code-quality review and fresh
scoped verification. **Code-quality review NOT PERFORMED in this assignment.**
Runtime/tests/formatter/VM/network **NOT RUN by this reviewer**; no production,
delivery/backing budget, activation or full M3 acceptance is inferred.

Parent's pre-format receipt records26 tests/0 failures, seed21108026, exit0 and
429 identical before/after source hashes. It is actual evidence for that earlier
source. The parent subsequently canonical-formatted only the four additions
and the [format receipt](h1-preparation-format.json) records formatter and global
check-formatted exit0 with the four reviewed hashes. Fresh tests of the currently reviewed
formatted identities remain pending; this report does not relabel the earlier
GREEN as a newly executed final check.

## Contract trace

| Requirement | Current implementation and test evidence |
| --- | --- |
| Exact bounded input grammar | Preparation25–29/68–84 requires exact3/7-entry maps with required keys; extra keys/structs reject. Scalar method/nil-PID/timeout validation114–122 precedes request nested walks. Address359–367 inspects only4/8 fixed tuple cells. Tests72–122/326–393 exercise invalid maps, overrides, tuple/component bounds, enum/timeouts and improper forms. |
| Independent logical and backing limits | URL351–357 limits1..65536 and backing≤65536 before parsing. Pairs239–262 separately account fields≤256 with32-byte charge and trailers≤128 with2-byte initial/4-byte per-pair charge; backing occurrences≤65536 each. Trust369–395 limits nonempty proper list≤128, each1..65536, aggregate logical/backing≤1048576 and per-leaf backing≤65536. Composed source backing caps1114112/196608 follow from these independent components. |
| Bounded rejection order | First excess field/trailer/cert cell rejects at240–241/374 before head/tail contents are inspected. Semantic byte scanners, public trailer helper, copying, constructor enumeration and ETF sizing occur after the applicable finite grammar/caps. Unknown/improper forms return fixed atoms; caller payloads do not enter errors. Tests283–307 use valid cap prefixes plus50,000-cell unsupported excess content. |
| URL/origin/target preservation |401–414 ASCII/percent preflight precedes bounded URI parsing; no userinfo/fragment, host1..253, port1..65535 and HTTP(S) only. Origin root/absent path and no query enforced31. Request scheme/lowercase host/effective port match223–228; target230–235 preserves percent spelling/query order/present empty delimiter, with `/` for absent path. Accepted URL is copied unchanged. Tests45–70/193–214/254–281/395–430 cover case/default ports, IPv6, exact65536/+1 URL and target-aware field charges. |
| Field/trailer semantics |264–286 enforces ASCII token names and binary value byte grammar. Declaration298–340 limits128 tokens independently across all Trailer/Connection fields before public `HTTP.Trailers.upload/2`;289 prohibits nonempty trailers with nil body, and helper errors collapse to invalid_trailers. Pair copy343–349 preserves spelling/order/duplicates. Tests216–229/309–324/432–506 cover declared duplicates, forbidden/Connection-nominated names, OWS, controls, byte/count limits and128/129 declarations. PID is retained only as a term, without producer ownership or interaction. |
| Canonical policy revalidation |124–221 validates exact Policy struct shape, compact origin/host, address and parsed field consistency. Options152–181 and SSL185–206 pattern-match fixed finite grammar; arbitrary option tails do not enter generic enumeration/equality/ETF. Certificates are bounded before compact-leaf traversal; SNI equality against≤253 generated integers constrains its accepted shape before ETF. Valid structural copies are accepted; there is no construction-provenance or unforgeability claim. Tests231–251/583–597 exercise forged/malformed options, inconsistent fields, extra struct entries and noncompact leaves. |
| Compact retained leaves/ETF |34–36/94–102/343–349/434–445 copy origin, host, URL, target, every field/trailer name/value and opaque trust byte leaf. SNI is generated from bounded host. Final external_size38/174 applies only to validated fixed SSL/socket trees and is≤1048576; it is compatibility, not heap accounting. Tests124–191 distinguish opaque payloads,128/129 certs,65536/+1 leaf, aggregate equality versus ETF overhead and oversized/aggregate backing. Tests508–598 first prove8192-backed source slices and compact whole output trees. |
| Complete scalar manifests | Constructors463–505 traverses only validated source/canonical values, counts every binary reference occurrence, all maps including struct keys, fixed tuples/lists, atom/integer/PID terms. `:maps.fold` includes `__struct__`. Manifest509–532 contains fixed scalar maps, source-plus-owned backing coexistence and pair-reversal extra cons, with no caller/PID/binary payload. Tests600–673 use literal entire-tree counts and scalar inspection, including SNI/PID occurrences. Parsing/copy/ETF/serialization peaks remain open. |
| Fixed partial facts/closed activation | Accounting6–76 exposes only facts/0 and activation_status/0, pinned cohort/runtime/profile, separate256/128/16384 pair facts,64-bit skeleton derivations, upload65536/framing9 and source caps. All P0–P6 remain unqualified with fixed reasons and explicit P4 coverage. No evaluator, caller proof constants, activation total/success or process/I/O/scope/adapter path exists. Accounting tests5–103 independently check arithmetic, identities, repeated refusal and absent caller-proof API. |

Independent Python reconstruction from literal source/canonical trees—not the
production walker—confirms HTTP owned logical/backing50, binary3, cons17,
tuples2→17/4→2, map7→1, atoms31, integers17; request source54 and owned62 with
coexistence116, source/owned maps7/9 and binary occurrences5/6; TLS cons37 and
integers30. Independent charges are `1+1+65502+32=65536` and
`2+1+65529+4=65536`; pair skeletons10240/5120/655360 and upload framing9.
These are constructor facts, not VM representation or native delivery proof.
Referenced-backing behavior itself still needs the actual pinned-runtime tests.

## Reporting findings and evidence limits

No inaccurate failure root cause or counter was found: original policy failure
was Enumerable on a Policy struct; request fixture expected65537 but retained
131074 backing; accounting red included the expected missing API plus two
unexpected literal integer counts16/29 rather than17/30. Corrected struct walk,
compact fixture and independent port counts match the current source/tests.
The missing accounting API alone after repair3 remains EXPECTED_RED, not a
fourth unexpected failure. Received counters remain initial unexpected3,
successful targeted Sol repairs3, unsuccessful0, Astra0.

Two related status clarifications were sent to parent and are **RESOLVED** in
the final documentation:

1. Design286–295 and plan346–364 now separate pre-format26/0, completed
   formatter/global check exit0 and pending independent implementation review
   and fresh formatted tests. The format receipt records the four exact input
   hashes and both completed command outcomes.
2. Design290–291 explicitly identifies the linked PASS as the prior written
   **design/plan** specification review. Plan352 explicitly labels the command
   as the pre-format strict implementation checkpoint. Neither promotes it to
   final formatted or code-quality acceptance.

No actionable specification finding remains. These reporting clarifications
did not reveal an executable specification defect or require source edits.
No runtime predicate or existing test was weakened.
Final code-quality review and fresh formatted-source tests remain required.

## Fresh checks and handoff

Read-only Git identity/state, full numbered source/test/design/plan inspection,
failure/green receipts/logs, Python literal arithmetic, SHA-256,22+4 test
declaration count and forbidden process/I/O/runtime-API scan completed. The
pre-format429-file maps match each other. Static scripts exited0; report
whitespace and final input-hash stability are checked before handoff. No Mix,
VM, format, network, executable/shared-doc edit, commit or delegation ran.

Task status **DONE for implementation specification review only**. Reviewer
repair rounds0; received pure-task unsuccessful0/Astra0 with the three successful
repair validations preserved. All reviewer commands finished; no reviewer runtime
session/process was started or remains. No design/product decision or escalation
gate is needed. Parent owns the separate quality review,
fresh final checks and any later commit decision. P0–P6 and numeric activation
remain NOT ESTABLISHED.

| Reviewed formatted input | SHA-256 |
| --- | --- |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_preparation.ex` | `114dfce56ad02ee65b588caec861ad7c6b46097b06690cb5af5ed8504beadf56` |
| `apps/gaoxy_proxy/lib/gaoxy/proxy/managed_h1_accounting.ex` | `e450888a458a4d1d5205b2c08563d34621bdce7b953fcd6fb72c75ded038febe` |
| `apps/gaoxy_proxy/test/managed_h1_preparation_test.exs` | `3d30aeb065362967ef66a03f44cfdca2c8473b5f57e805d9ea84852a2f7116a4` |
| `apps/gaoxy_proxy/test/managed_h1_accounting_test.exs` | `691188a72264f3a50d15a958c6f1b8ce5ba08efb8c3511c21ab0a9eb969737f0` |
| Current design | `d4255df1ebd57f78b73d0d359fa625514b537ddb37a140967e40f395f7aa44e6` |
| Current plan | `e50d7b97e65ef7ebdc44ba8f0c4f6867bf3eb0c4e54af975e626959e22864b14` |
