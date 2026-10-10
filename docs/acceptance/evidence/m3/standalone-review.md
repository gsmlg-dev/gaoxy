# Independent standalone specification and quality review

Date: 2026-10-10. Reviewer: `/root/m3_udp_implementation`, direct independent
review assignment. **Specification verdict: PASS for the standalone source
slice after S1/S2 repairs.** The separate quality review below also passes.
Production repairs belong to root; this reviewer owns only the independent
fixture and review report. This does not approve the reviewer's own UDP work or
establish overall M3 acceptance.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway`.
Branch: `codex/m3-gateway`. Baseline:
`22b76e8051ddaf09e36797cb781b9b119870a9d4` plus shared task changes.
Specification: `docs/designs/m3-standalone-generations.md`.

## Specification re-review — PASS

| Contract | Source and fresh evidence |
| --- | --- |
| Pure prebind data validation | Fixed handler/key/protocol/h2c/TLS/limit allowlists; binary bounded IDs and Registry names; no arbitrary modules or input-created atoms. Config validates routes, compiled size and normalized HTTP service before owners or listeners. |
| Bounded files and one reload deadline (S1 closed) | Shared `Config.read_file` rejects nonregular files and oversized stat sizes, reads at most 1 MiB plus one byte through a raw descriptor, and closes it in `after`. RouteConfig performs loading, JSON/target validation and compilation inside Generation's owned preparation worker through `prepare_with`; one remaining deadline governs snapshot, prepare and activation. Existing finite receipt headroom confirms worker cleanup. FIFO returns an error within the independent bounded yield, without activation. |
| Custom response limits (S2 closed) | Config validates fixed output against the normalized listener profile before returning options. Supervisor registers immutable protocols/HTTP limits as the store Registry value; Server carries that profile into reload validation before prepare/CAS activation. H2 counts generated status and framing bytes/fields; H1 reserves its possible connection field and serialized head bytes. Both independent count and byte startup/reload regressions pass, retaining exact old H2 response, generation and listener port. |
| Store/listener lifecycle | Registry, named Generation stores, then ordinary runtime under `rest_for_one`. Normal shutdown stops runtime before stores. Mixed failed-start proof retains explicit startup error, absent Registry/runtime, connection refusal and same-SO_REUSEADDR port rebind. No assertion about an OTP linked EXIT mailbox event is needed to prove cleanup. |
| Snapshot/name/resource seam | Groups-owned compiled-router and OTP name seams are present and compile. Generation/resources/loader tests now execute green rather than remaining implementation-pending. Ownership/pin policies retain their separate Groups review. |
| Stable reload and rollback | Invalid data cannot alter the router; activation checks the expected generation and deadline. No listener/address/TLS mutations or HTTP management endpoint are introduced. Exact mixed reload/rollback tests pass. |
| Finite budgets and atom safety | Snapshot-byte capacity is explicit; conservative H2 connection/stream/writer reservation remains separate from core defaults. Names use binary IDs through Registry. |

No unresolved actionable standalone specification finding remains in the reviewed
slice. Broader owner-crash/restart qualification, H2 streams across repeated
changes, proxy guardian changes, browser/consumer/load and milestone acceptance
remain separate gates; source ordering is not substituted for their execution.

After this review, root independently identified a Generation postpublication
resource-release path that can delay the CAS activation receipt. Root owns that
Task5 repair. S1/S2's bounded loader and custom static validation remain resolved,
but full reload/deadline and sustained-load qualification must wait for the
companion repair and its fresh freeze; this review does not clear that known gate.

## Separate quality review — PASS

Performed after the specification re-review. Read Config/Application/Supervisor/
Server/RouteConfig/StaticEndpoint and the Generation loader/preparation seams.
The fixes reuse the existing supervised preparation worker and shared bounded
reader, preserve expected error tuples, and do not introduce another task owner,
public management endpoint or dependency workaround. Immutable listener context
is carried by the existing Registry, avoiding mutable cross-service validation
state. Static framing checks match emitted status/content-length and preserve
304 representation length and HEAD/bodyless behavior. No actionable correctness,
maintainability, ownership or scope finding remains in this source slice.

The independent FIFO fixture kills its owned reload task before closing the
keeper on failure, so it cannot activate after cleanup. The raw H2 helper has an
absolute receive deadline, exact 200/body checks and owned socket closure. All
source repairs and the ordinary standalone fixture belong to root; no reviewer
production edits were made.

## Exact runtime evidence

Initial independent run `standalone-independent-red.log`: **5 tests / 5
failures**, seed **656795**, exit **2**. Three reached expected implementation
failures; two exposed a fixture-only HPAX iodata conversion error before reload.
Retained that log and normalized only the helper's iodata to binary.

Corrected independent red command:

```sh
nix develop --command bash -c 'export ERL_FLAGS="+S 2:2"; export MIX_ENV=test; set -euo pipefail; unbuffer mix format apps/gaoxy_server/test/standalone_independent_review_test.exs; sha256sum apps/gaoxy_server/test/standalone_independent_review_test.exs; unbuffer mix test --warnings-as-errors --max-cases 1 apps/gaoxy_server/test/standalone_independent_review_test.exs | tee docs/acceptance/evidence/m3/standalone-independent-red-fixture1.log'
```

Result: **5 tests / 5 expected implementation failures**, seed **331925**, exit
**2**. FIFO yielded `nil` after 250 ms under a 50 ms reload budget. Both invalid
startup profiles returned `{:ok, options}`; both invalid reload candidates
returned `{:ok, generation}` after an exact `200` / `old` response. VM cleanup
completed and the exclusive Mix window was released to root.

Fresh parent post-repair evidence inspected directly:
`standalone-repair1-fixture2.log`, strict compilation **exit 0**,
Generation/resources/loader **21 tests / 0 failures**, server config/route/
standalone/independent **18 tests / 0 failures**, seed **459271**, shell **exit 0**
reported by root. All five independent regressions pass in that server command.
Parent runs own the green execution; this reviewer inspected the log and source
without concurrent Mix. The earlier repair1 log retains its linked-EXIT fixture
failure; removing that non-API mailbox expectation preserves every runtime
cleanup assertion and the fresh gate is green.

## Re-reviewed source SHA256

- Config: `437920e5c86ae5b7af8a79ce517752caa37b992d16e9288e36872f1e3a085867`
- Application: `d2fa2f01fc8bc86eb3f0bb281340e24c1e61913d360e7f4825f4fc5774b3b457`
- Supervisor: `fb5d68f5bd6b24ce2f5abdfe3002f81080325f87906502f81ad1b8f176dd27a7`
- Server API: `53c5d0ecee486b2f1568cf9f1dfb83bbaaa708f69ebd2ec86562fe43c433205c`
- RouteConfig: `5db93701da755bd1ca977c191e79e650bd9e58108ed28842491f4031dc8b95fc`
- StaticEndpoint: `633a9dc349eaf92add63fcdda799e0ed5d8f37878739a7c78e143734017c12dd`
- Generation loader seam at inspection: `b17ca27e8026370066840a873afe09c36bd0b25594e6e382134877a046df9b1c`
- Independent fixture: `33e3aec40717286a800a4ac82fa0553c04101b760db081a92da91c07b8cd4cd9`

Groups owns subsequent formatting/resource-bound changes to Generation and its
fresh qualification; those do not silently inherit this inspected hash.

Reviewer standalone production repair rounds **0**; fixture repair rounds **1
successful**. Prior UDP counters remain attempted **2**, unsuccessful **1**,
Astra **0**; no new escalation gate. Commands finished and no reviewer Mix is
active. No commits, publication, deployment, dependency edits, skipped tests or
weakened runtime assertions. No user decision or external permission is needed.
