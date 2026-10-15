# Managed H2 group source foundation complete SPEC review 1

FAIL — one unresolved medium finding, SPEC-GS-001. CODE may not start for this candidate.

Candidate SHA256 `7980deac44d18347ce9fab17b3ae0f7428f9d9ff0a8c255705e784ffd23e9217`, HEAD `192745a4104b65d84c8de05d0fefff19b4de90fc`, branch `codex/m3-h1-resource-foundation`. All33 source hashes and33 evidence hashes/byte lengths authenticate and remain stable. Exact current source hashes are in the companion JSON. Production envelope is `c8a63c08ce6852d73a094e9172d5ca61817d68744db949ce478c7aa656831947`; formatted test is `de93f47cddb26be6b8d6dfb5a22cdc3a83b23576892579564a5cd2c1cf4c8820`.

## SPEC-GS-001 — missing feasible inclusive joined boundary

`managed_h2_group_source_test.exs:306-319` checks raw8192 acceptance/raw8193 rejection and joined65537 rejection, but never selects a joined65536 value. Acceptance `m3-managed-h2-group-source-foundation.md:18` incorrectly says joined65536/65537 remain asserted. The old fixed-envelope65536 test calls prepare/2 directly and uses raw origin beyond8192, so it cannot cover the group wrapper.

The fixture is feasible under unchanged selected semantics: raw_port_origin(8192) plus target(57344) gives URL65536. ManagedH2Preparation:455-481 reconstructs effective authority from host/integer port and omits default443, yielding upstream.test (13 bytes). Four pseudoheaders, two trace fields and default user-agent total7 fields/57658 bytes. URL+target+raw field payload is122905<=196608. Thus an additive exact65536 success regression can retain all existing assertions and delegated checks. Actual success remains to be run by root; the reviewer executed no Mix.

Add exact raw URL/target and compact valid envelope assertions at65536, preserve65537 rejection, retain this failed review, re-freeze/reverify and obtain full SPEC PASS before CODE. No production defect was identified.

## Other requirements checked

Exact6/7/8-key shapes, finite malformed-source errors, complete bounded preflight before copies/ETF, logical/backing bounds, retained compactness, raw percent/leading-double-slash/empty-query semantics, selected TLSH2/h2c and unchanged forbidden/effective-header/upload delegation conform by source inspection and authenticated preliminary evidence. Maximal256-pair complete source has independent wrapper upper217 and total upper134366<=205337.

The original author test hash `b11d39449bbd4609bb914247ddefb21df03cb2c73691191c4639299f1782a3e5` is preserved. Initial-to-formatted test comparison retains identical nonwhitespace/noncomment tokens and quoted literal contents; assertions are unchanged. All old tests and other tracked boundary files retain baseline hashes. The only production diff adds56 lines to ManagedH2Envelope; no owner/probe/group/config/Session/reservation/dependency/live path changes.

Authenticated red2 records16/16 UndefinedFunctionError failures, exit2, zero skips/exclusions and unchanged baseline production. red1 zero-test custody failure remains separately preserved and rejected, never intended RED/PASS. Preliminary preformat107/0 exit0, format and postformat forced strict compile exit0 are recorded historical results. Full CODE and fresh final gates remain pending; no reviewer runtime result is claimed. All7 receipt logs and collector hashes independently agree.

Original non-live readiness predates raw clarification and remains design readiness only. ACCOUNTING_NOT_READY and PROPOSED_UNPROVED reserve remain unchanged. All inherited failures/counters and custody failure1 are preserved; source repairSol0, this failed SPEC1, Astra2/2 exhausted. No recovery, #97 pursuit, publication or activation occurred.

Read-only review complete; all commands finished. Only these two assigned /tmp artifacts were written. No product decision is needed; root can apply the additive test repair and re-review.
