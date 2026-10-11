# TLS95 fixture repair1 independent changed-byte review

Task `m3_tls95_fixture_repair1_independent_review`, direct independent Sol;
**DONE — PASS_STATIC** for specification compliance and code quality.
All three original findings are closed in the repaired bytes. No new actionable
finding remains. Candidate GREEN, qualified baseline RED, compilation and all
runtime cases remain **NOT RUN**.

Worktree `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`, branch
`codex/m3-gateway`, baseline `b2ac78b518f459ec2c95b7823226640413f2ca95`
from parent/freeze. Only this report and its
[JSON receipt](tls95-fixture-repair1-review.json) were created. Original FAIL
reports, parent tooling and other changes are preserved.

| Original finding | Re-review | Repaired driver evidence |
| --- | --- | --- |
| TLS95-FIXTURE-01 | CLOSED_STATIC | Custodian expectation registered before spawn332–333; every successful open retained immediately779–788; cleanup reconciles pending opens850–860 and drains before scope enumeration875–891, then joins custodians. |
| TLS95-FIXTURE-02 | CLOSED_STATIC | Job result and normal DOWN required977–1004; custodian successful open/result required1009–1039; cleanup requires result_ok/join_ok as well as joined/normal_down/notforced952–960. |
| TLS95-FIXTURE-03 | CLOSED_STATIC | Receipt registered/ACKed before await494–501/794–806; pending initial registrations reconciled862–873; existing cleanup callers sweep every original receipt488–524/881; complete retained-receipt results gate PASS942–955. |

A failed primary open wait no longer discards a successful late scope handle.
Unknown/open-failure evidence remains cleanup FAIL. Each original retirement
receipt is retained before the helper waits, with exact scope/terminal expectation;
each receipt check and acquisition is captured independently so an error does not
skip the remaining originals. The final successful acquisition/result check does
not erase earlier failures. All cleanup uses the original absolute deadline.
Successful helper results remain distinct from public unconfirmed terminal:
the unknownCA producer returns a successful structured result containing the
pre-registered exact cleanup_unconfirmed premise; a captured fixture exception
cannot pass on normal DOWN alone. Primary errors remain separately recorded.

The current complete plan/inventory and repaired full driver preserve the
source-derived3/4 oracle and two baseline inventory selection. Expected baseline
1/2 count mismatches accumulate through both completed GETs, same connection,
exact bodies/ACKs and original completion rechecks, commanded idle close and stable
zero barrier, followed by confirmed cleanup. Independent A/B live retirement,
B survivor reuse, two counted single A-retired checks, real empty-trust unknownCA,
exact public alert and unconfirmed completion/receipt expectations remain intact.
The unchanged peer still requires verified H1 absentALPN/null or H2 exacth2 and
retains inherited framing/finish_hold/closed/wire-drain/join semantics.

No budget or timeout is added: candidate682/baseline240 snapshot calls;
case120/201/40 and window40; a single budgeted public snapshot invocation;
consecutive exact selected maps;50ms maximum snapshot and25ms polling interval;
ready+18s primary/30s cleanup with bounded owned fallback at32s; original6s request,
2s connect and30s idle;45s peer ready/lifetime. Registration reconciliation adds
no helper starts and receipt sweeps reuse scope retirement callers, leaving healthy
inventory/retirement/handshake starts5/9/4 under cap10 and custodians/producers≤2.
Forced owned cleanup remains FAIL. No private process/socket discovery, client
kill, injection, quota, System.halt or weakened assertion was added. The driver
still reports cases/cleanup/summary before returning or raising for the separate
same-VM identity wrapper.

Fresh static verification: **15/15 current freeze hashes,63/63 inventory inputs,
35/35 embedded source references match**, including unchanged historical39/helper
bytes. Three Python peer ASTs parse without module imports/execution/bytecode.
Original initial-review MD/JSON SHA-256 values remain
`e8bbb9aa56d7cb723f1d1b75fa3f9094bdf31dfc4eaf9581e7f2c978336b09c5` and
`fcb731de40173dfbd2a2eb0db4a7ce16c4afd9eceffdd6db094d5e04b70929c3`.

Reviewed source/document SHA-256:

- Driver: `3f51ec383ffabe16ae3d5a9c223505eedce37282bcb14850265a7b8880e70074`.
- Peer: `5fba2a96dc3274f7b9ef3f1e2a893d76ab43f7a47d633e355254fd25ed715406`.
- Plan: `fe08cabba0590a9e1c8f08d8147b46462215b939d4326eb356af3b02d60d7bac`.
- Inventory: `d9d76bfd76bd64c6042d9d7b00c2f6eda8e2f2da010a84a6fb577aa7010957d0`.

The JSON receipt records complete frozen inputs, exact changed-path evidence and
closure of all original finding IDs. No Elixir AST/compile/runtime claim is made.
Parent tooling repair2 review is separate and this verdict supplies no VM/source/
native profile acceptance. Exact runtime5GREEN and qualified2RED remain required;
TLS byte/native/backing, arbitrary-history, full P0–P6, activation and M3 remain
unqualified.

Fixture counters remain Sol repair1/unsuccessful0/Astra0, with independent static
review now PASS and runtime pending. Historical specification Sol2/unsuccessful1/
Astra0 and tooling Sol2/unsuccessful1/Astra0 remain separate. Reviewer source/
implementation repairs0. No new product decision, fixture repair or escalation is
needed. All own commands finished synchronously; no VM/Mix/formatter/peer/import/
network/dependency/Git action, background job or delegation was started. Only the
two assigned reports were written. Review-output ownership is released on handoff.
