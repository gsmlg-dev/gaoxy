# HTTP Fetch 0.21 finite functional delivery review

Task: `m3_managed_contract_review`, direct independent Sol delivery review,
2026-10-11 Asia/Shanghai. Worktree
`/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline/HEAD
`4cc7a1a967d1b90a62d42db438316b10a03a1e16`. Own only this new report; preserve
other writers' changes and historical reports. The live pure H1 implementation,
its tests and author-owned preparation design/plan are expressly excluded and
receive no certification from this review.

## Specification and coverage verdict

**PASS for the dependency upgrade and the named finite managed functional
properties in the recovery1 evidence.** Full Task3, complete H1/H2 reservations,
transport-owner/adapter integration, matrix/load/soak gates and M3 remain
unqualified. Canonical H2 connection-capacity error compliance is **MISMATCH**
for both verified TLS H2 and h2c. This review does not equate it with PASS.

One documentation clarification was requested and **RESOLVED** before final
delivery: the earlier checked capacity requirement at
`docs/plans/m3-upstream-transport.md:249–251`
named total/active/idle/connecting/stream/pending limits without distinguishing
source-derived finite ledger guarantees from states exercised in this runtime.
The39-case fixture directly tests held active/unread request saturation, idle
reuse, H1 active connection saturation, H2 draining-owner capacity and pending0.
It never holds a preparing or connecting phase for a saturation test; sampled
preparing counts are0. Source Scope83–97 reserves finite connection slots before
dial, and facade293–305 bounds the preparing request ledger. Those establish
source constraints, not a recorded saturation test in those states. Final
plan249–255 distinguishes source inspection from the exercised states and
explicitly records held connecting/preparing saturation NOT RUN. An unchecked
preactivation requirement275–277 retains held setup and preparing/admission
turnover validation; no obligation is erased and no activation gate is lifted.
This reporting correction creates no new dependency blocker or fixture expansion.

| Checked functional item | Evidence and practical limit |
| --- | --- |
| Opaque resource/no fallback/finite admission | Original public scopes remain opaque; same-origin independent scopes use distinct peer connections; retired and conflicting-policy requests return exact errors without raw request bytes or extra accepts. Held request saturation and H1/H2 occupied connection cases use exact counts and zero pending. Source slot/ingress bounds supplement these finite runtime states; no exhaustive preparing/connecting-state test is claimed. |
| Unequal budgets/reuse/absolute request deadlines | Three profiles reuse under different total/connect budgets and exact peer connection identity. Three700ms total deadline expiries occur within650–1700ms while5500ms work remains live, finishes exact body and supports further reuse. Connect-budget reuse is covered; independent stalled-connect expiry is not exercised. |
| Retirement/late checkin/isolation | Idle close, graceful pending receipt and late rejected admission, normal late checkin closure, forced abort and creator death, repeated/concurrent generation receipt waits, exact original completions and independent live B body/completion all pass. H2 abnormal request uncertainty stays explicit while generation retirement separately confirms cleanup. Fragment257 failures preserve exact unconfirmed completion, connection-wide sibling failure, independent scope progress and public zero ledger before explicit replacement. |

No assertion weakening, private dependency process/API, fallback, dependency
source patch or failed-request replay was found. Prior independent specification
and code-quality reports apply to exact recovery1 probe hash82c066013c24d29da469f1ec5b24be8321d17810f85b41ea37c8a274eb7547d2.
Normal/graceful/deadline completions remain exact ok; abnormal H1 remains exact
ok, abnormal H2 accepts only exact ok/unconfirmed with repeated/concurrent and
cleanup equality; fragment loss remains exact unconfirmed. Both256 positive
and all257 negative variants remain present. Historical initial11,
diagnostic11, repair1runtime24 and repair2format failures remain preserved.

## Separate code-quality and evidence verdict

**PASS for executable delivery quality and recorded functional evidence.** The
upgrade changes only the two exact direct version requirements and seven
coordinated lock entries. Current adapter code differs from HEAD only in
comments; `http_version: :http1` and `http1_reuse: false` remain. All196 current
installed files match provenance, and seven lock versions/outer checksums match
the release cohort. Existing release/175 runtime-blob provenance is recorded
evidence, not a new network fetch by this reviewer.

Fresh raw-log verification independently matches39 unique case receipts in the
receipt's exact order,39 successful cleanup records, peer ok and scope ok in
each, no cleanup-pending/fixture exceptions/failure markers, two exact canonical
mismatch blocks and final resource-property marker. The execution receipt records
exit0,32.688s, no timeout and no owned peer before/after. The preflight receipt
and log record strict format/compile and18 tests/0 failures, seed21106026, exit0.
The three preflight/runtime before/after maps are identical across all425
entries. Current executable fixture/helpers/peer/adapter/dependency inputs match
their frozen identities. Parent-owned documentation changed after runtime;
the runtime's425-map claim applies to that execution, not today's entire tree.

The scoped current documentation preserves39/39 as finite functional evidence,
separate from byte accounting, managed integration and full M3. Its P1 references
remain partial/conditional raw logical8192/backing10922 and singleton-backing
facts; they do not certify complete SSL credit, decrypt output, handoff, parser
overlap, native backing or activation budgets. Remaining local obligations are
unqualified work, not automatically external blockers. The latest recorded
upstream observation at2026-10-10T18:17:51.684042Z records release0.21 and
issues86–89 open with required types/labels:86 blocker,87/88/89 needed in their
request documents. TLS/h2c#89 observations remain exact mismatch; no production
normalization is added. H2#86 receives no local dependency workaround.

Two broken acceptance links for#87/#88 at78–79 were found and parent-fixed to
`../dependency-requests/...`; both now resolve. Twelve scoped current Markdown
documents passed local link-target checks. The capacity clarification above
is resolved in the final parent-owned plan. No actionable specification,
code-quality or reporting finding remains in the reviewed delivery scope.

## Checks, limits and handoff

Reviewer used read-only Git/source/log/document reads and Python standard-library
hash, receipt, raw-log, frozen-map, dependency-cohort, comment-only adapter and
local-link checks and scoped `git diff --check`; all verification commands exited0.
No Mix, network, fixture,
live H1 implementation investigation, source mutation, upstream action or commit
ran. This report is the only reviewer change; all commands finished and no
reviewer runtime process/session was started or remains.

Task status: **DONE for the independent delivery review**, specification PASS
followed separately by code-quality/evidence PASS. Parent resolved both
documentation findings and owns subsequent final delivery checks. No product approval
question or new architectural decision is needed. Cumulative Task3 unsuccessful
Sol validations2 (runtime1/format1), initial FAIL1 and diagnostic FAIL1 separate;
Astra recovery1 of2 completed, unsuccessful0. This delivery review uses0 repair
rounds. Existing finite-wait/cooperative-shutdown limitations remain; successful
joined cleanup and no-peer receipts establish the executed run's shutdown,
not a universal forced-shutdown guarantee. No claim about ongoing H1 work,
commit, merge, publication, release or deployment follows.

| Evidence | SHA-256 |
| --- | --- |
| `managed-probes-recovery1.json` | `77f7b8780f4df82c3cdbf2d403989dbd2c00db170588fc537eddc0fc125aca07` |
| `managed-probes-recovery1.log` | `623e66f2b32df3cc59390b315410e7aaaf320c92cda1d9c404a99b50196f0d5a` |
| `managed-preflight-recovery1.json` | `514f682b986abb45fb283e171799d9d68c5c8061841b47fd4e5fede7fd48772c` |
| Identical425-file runtime before/after maps | `c79a909bb788b9c533ddf84985f19e018c4182a80ba14455da88f74ae3d06bcd` |
| `upstream-status-current.json` | `d922f5a90368058423f30d93e84fb7f57713d39899fc943665132a16809cfc15` |
