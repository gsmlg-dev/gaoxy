# Managed-H1 matrix independent source specification review

**FINDINGS_SOURCE_SPEC1** — static review complete; candidate runtime NOT RUN.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Root-verified entry: `1426657e65d726629d618dcf03880df718375dd1`.

The explicit16 cases, shared fixture architecture, temporal causality, exact representation/trailer oracles and two-row browser source follow the approved design. Two lifecycle/deadline findings require targeted repair before runtime.

## F1 — P2: Check the case deadline after the final acceptance operation

`integration/upstream_transport/run.py` lines 435, 450.

Case.run checks self.deadline at line440, then performs the accepted event/identity checks at441-444 and finally returns PASS at448-450. Host.event/Host.call do not receive the case deadline (98-103,114-115). The final accepted-event round trip is outside the last20s guard. Shutdown has its separate allowed10s and is not itself the finding.

The promised20s case deadline is not an absolute execution bound, and can expire during the final fixture round trip without preventing PASS. Earlier case operations also receive new5s Host.call budgets instead of the remaining case budget, although the eventual line440 check normally detects those overruns.

Required change: Give case-owned fixture calls the minimum of their barrier budget and the remaining case deadline, and recheck the case deadline after the last acceptance/identity operation before starting the separately bounded shutdown. Preserve a separate10s shutdown budget.

## F2 — P1: Make owned-client cleanup unconditional and exception-safe

`integration/upstream_transport/run.py` lines 452, 463, 497, 505, 520, 523.

Case.cleanup invokes client.abort() without isolating errors (454-457). That method can raise from process wait/kill/wait or pipe closes (196-205). If cleanup raises, the main finally only host.abort() (520-523), with no independent-client sweep. A SIGALRM arriving while cleanup is running has the same escape. Client Popen has no dedicated process group (153), and Host.abort targets only the Mix process (133-141), so stopping that host does not join the separately spawned Python clients. Attached timeout similarly stops the fixture and closes the driver port without an explicit independent-client join acknowledgement.

The design requires finally to stop/join all owned resources on failure. A normal case failure followed by a cleanup failure/overall timeout can leave owned independent clients unjoined and lose the structured failing case receipt. This is a source lifecycle gap, not an assertion that a runtime leak has been observed.

Required change: Keep an outer owned-client registry and perform a bounded best-effort sweep in finally, isolating each cleanup error so every owned client is attempted. Make the attached-driver abort path explicitly bound/join its own descendant clients or arrange an owned process group with a checked shutdown acknowledgement. Retain all forced/unjoined outcomes as failures.

## Verification and limits

Eight owned source files and three canonical matrix documents match the frozen hashes; Python AST parsing passed for the three Python candidates. The exact client diff was reviewed. All proposed command gates remain NOT RUN. No Git, build, Mix, test, browser or runtime command ran. No repository files changed. Full reviewed-input hashes are in the companion JSON.

## Tooling incident

The first supplied-manifest read printed both manifests in full instead of a bounded projection, exposing a broad already-recorded source-name/hash inventory and producing truncated tool output. No filesystem enumeration or Git command was used; no source/private/key/trace file was opened through that inventory. Subsequent reads used explicit owned paths and bounded projections. Protected files were not intentionally accessed or reverified; the clipped display was not reread to investigate protected names.

All review commands finished with exit0. No new Sol repair round; inherited Astra2/2 remains exhausted. Whole Task6/Task5/M3 remain OPEN. No user decision is required for the ordinary targeted fixes.
