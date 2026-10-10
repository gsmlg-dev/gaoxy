# Independent review of the 0.21.0 layout, identity and CA delivery

Date: 2026-10-11 Asia/Shanghai. Task `m3_layout_identity_ca_delivery_review`;
separate direct Sol specification and documentation/evidence-quality assignment.
Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `6ef8a3ad8e26e2f4992adeaf9558199aef8105a5`.
Only this new review report is owned. Parent status-document changes, existing
untracked evidence and concurrent0.21.1 source-review work were preserved.

**DONE — PASS_BOUNDED_DELIVERY_REVIEW, after one documentation finding was
corrected and independently revalidated.** The exact reviewed delivery contains
source/identity supplements, remote metadata and documentation; no executable
product diff exists. Full M3 and P0-P6 remain unqualified. No managed activation,
TLS95 resolution, fresh protocol/test execution, push or publication follows.

## Exact frozen delivery

| Manifest | SHA-256 | Disposition |
| --- | --- | --- |
| Initial `.audit/m3-layout-identity-ca-delivery-freeze-initial.json` | `69a6386eb3fdacb4f8a4da653f014a30d58174e2c2e166a319016160d2910bcc` | Original20-file snapshot preserved after finding. |
| Reviewed replacement `.audit/m3-layout-identity-ca-delivery-freeze.json` | `65bd92ea48ea801a25b8d4f132bc82434e40d3ed92da4c2bc99a5741514dbf8d` | All20 listed files match; prior snapshot hash and repair explanation recorded. |

The final manifest includes the three authored proof/identity pairs, their
separate independent reviews, loaded-identity historical receipts/logs, remote
refresh3, four current status documents and the new patch qualification plan.
The replacement changes only the hashes of acceptance and transport design;
all other18 frozen files are identical to the initial delivery.

The manifest's unchanged executable snapshot is
`post-comment-format-source-after.json`, SHA-256
`155539a9a0e7cb880d636a618882b2df7f910dc156e4bdeae6892b06b7f57553`.
All429 listed executable-input hashes independently match current files. The
tracked diff contains only the four status documents. The seven HTTP-family
lock entries and exact proxy Fetch pin remain0.21.0. Concurrent patch archive/
source-review work does not change those installed-input observations.

## Finding and repair

The initial acceptance introduction called refresh2 "Fresh remote status" and
stated that the latest published/installed artifacts remained0.21.0. The design's
"Current external gate" introduction made the same claim. Both contradicted
refresh3 and their newly added later paragraphs identifying publication0.21.1
and installation0.21.0. This was a delivery-status inconsistency, not a runtime
or dependency defect.

The finding was reported to the parent before any authored-file mutation.
The parent changed only those two introductions to reference refresh3 and
explicitly distinguish GitHub/Hex published0.21.1 from installed0.21.0, keeping95
open and requiring containing-source/installation/requalification before
clearing installed findings. Independent replacement-manifest and wording
checks passed. No unresolved actionable finding remains in this frozen delivery.

## Specification and quality assessment

The bounded technical reviews remain unchanged:

- [Native object review](h1-native-object-layout-independent-review.md) accepts
  conditional Binary/message/fragment source formulas under stated LP64
  premises. Actual translation-unit definitions, native ABI, loaded-layout
  equivalence, other object classes and retained multiplicities remain open.
- [Loaded artifact review](h1-loaded-identity-independent-review.md) accepts34
  point-in-time public code-MD5/disk matches and full-file BEAM/emulator hashes.
  Original compiler inputs, source rebuild, all native dependencies, hot-code
  exclusion and scope-lifetime profile enforcement remain unproved.
- [Policy/CA review](h1-policy-ca-overlap-independent-review.md) accepts warm
  persistent-term sharing and conditional explicit-DER constructor components.
  Cold loading/replacement, global snapshot identity/preload/immutability,
  helper/serializer peaks, ETS/process copy costs and release remain open.

The four status documents accurately preserve those boundaries after the
wording repair. Conditional source constants and constructor/event subtotals
are not treated as a complete P2/P3 reservation, and point-in-time executable
identity does not remove original compile-input or lifetime obligations.
Global snapshot exclusion does not extend to mutation-created owned copies or
cold-loader preparation peaks. Task3's complete prerequisite checkboxes and
Tasks4–8 remain gated; M4 cannot start from these partial results.

Historical pending-review fields remain intact in authored receipts. Separate
review reports record their subsequent disposition. The identity initial and
repair1 receipts remain FAIL/exit1/metadata-null, and their byte-exact renamed
logs match their original stored hashes. The final PASS identity receipt does
not relabel either failure or erase diagnostic counters.

## Publication and next-plan boundary

[Refresh3](upstream-status-refresh3.json) is a remote-state receipt observed at
2026-10-10T19:52:26.851894+00:00. It records GitHub tag v0.21.1, Hex latest0.21.1,
issues86–89 closed and95 open, while recording the installed cohort0.21.0.
The current lock/pin inspection agrees with the installed part. This reviewer
performed no live remote recheck, and metadata/issue closure is not containing
artifact or TLS qualification.

The [patch qualification plan](../../../../../plans/m3-upstream-0.21.1-qualification.md)
keeps all execution checkboxes open. It requires finishing/committing the
current0.21.0 evidence before replacing dependency inputs; preserving old
sources/evidence; verifying seven archives, actual tag/tree identities and
internal requirements; independently reviewing containing fixes; coordinated
pin/lock changes; fresh scoped format/compile/compatibility and applicable public
regressions; and independent review of that new delivery. It preserves assertion
strength, finite peers/deadlines and cleanup, keeps TLS-dependent gates blocked
without an independently qualified95 fix, and forbids publication/deployment.
Those boundaries are consistent with current authorization and product scope.
This review is not approval of an unexecuted0.21.1 cohort qualification.

## Verification evidence

All successful review commands below exited0. Scoped `git status`, `git diff`,
source/receipt reads and SHA-256 rereads established the exact checkout and
documentation-only tracked change. Independent Python checks verified initial
and replacement manifest identities, all20 replacement file hashes, their
two-file delta, unchanged429 executable inputs, historical FAIL log mappings,
the seven0.21.0 lock entries and the exact Fetch pin. Eleven frozen Markdown
documents have balanced fences, no trailing whitespace and123 resolving local
links. `git diff --check` passed. Final report/hash preservation was rechecked
before handoff.

Existing test claims are tied to their original receipts and logs:

| Historical check | Original observation | Independently read result |
| --- | --- | --- |
| Pure H1 preparation/accounting | `h1-preparation-final.json`,2026-10-10T18:50:44.670536+00:00, seed21108026 |26 tests/0 failures; exit0. |
| Installed0.21.0 compatibility | `compatibility.json`,2026-10-10T17:02:04.454189+00:00, seed21102026 |90 core +196 HTTP +156 proxy +18 server =460 tests/0 failures; strict format/compile/test exit0. |

Raw logs independently confirm those counts. The status documents link the
original exact receipts and keep them separate from historical0.20/0.19
results, managed acceptance and future patch qualification. No new26-test or
460-test execution occurred for this delivery review. Newly executed checks
were source/hash/document consistency checks; they are not protocol tests.

The initial review checker passed all identity/history/link checks while the
semantic wording finding remained open. After parent correction, the separate
replacement checker reported:

```text
PASS replacement freeze20 with only2 reviewed doc corrections; unchanged429 source identities;123 local links/fences/whitespace; historical raw log counts460/0 and26/0; publication distinction corrected
```

## Counters and handoff

Separate delivery-review repair record: one parent documentation correction
round, independently validated successfully; zero unsuccessful repair
validations, zero implementation repairs, Astra0. This review agent made no
diagnostic or product repair. Earlier native/identity/CA and historical runtime
counters remain unchanged and are not reset by this task. No escalation gate
applies.

No further product/user decision is needed for this bounded delivery. The
parent owns the authorized local commit, exact staged-content recheck and
subsequent patch qualification. This report supplies review evidence; it does
not stage/commit any file or claim that a commit already exists.

All own commands finished; no VM, Mix, C compiler, network/upstream operation,
background session, agent, dependency/product edit or peer-process action was
started. Only this report was written; all concurrent edits were preserved.
Runtime/protocol gates remain NOT RUN by this reviewer. Remaining risks are
the explicitly open compile-input/native/lifetime/P0-P6/TLS95 obligations and
the unexecuted new-cohort qualification, not an approved activation budget.
