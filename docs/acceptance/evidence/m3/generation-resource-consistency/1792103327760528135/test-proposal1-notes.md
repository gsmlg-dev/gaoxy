# Resource consistency test proposal 1

Task: resource_consistency_tests. Direct assignment. Proposal ONLY; NOT RUN.

Repository/worktree inspected: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`.
Baseline inspected: `8160e8bb6d7f55dc836b1aed0403cc2304a539bf`.
No repository files changed; only the two assigned `/tmp` artifacts were written.
No mix/Nix/runtime/formatter/build/Git mutation or child agent was invoked.

## Proposed coverage

The complete proposed file defines 61 ExUnit tests after parameter expansion:

- 20 root sidecar refusal tests: missing, extra, substituted, and old owner_epoch across public activation, direct Store activation, preparation via a static Router input route, initial compiled router, and initial routes.
- 20 two-level static recursion refusal tests: the same four defects across the same five paths; outer, middle and leaf false manifests agree but actual leaf target membership differs.
- Six callback error tests: non-list, invalid list element, incomplete provider metadata, raise, throw and exit, each through public/direct activation and preparation.
- One malformed static Router test covering non-struct target, non-list routes, and malformed route maps through public/direct activation and preparation.
- Two generic provider acceptance tests: exact five-key and six-key public pin shapes; reordered/duplicate raw sidecars accepted with exact supplied Router preserved. Test deliberately preserves the actual existing Router.compile reverse resource collection order for two input routes.
- Raw 64 distinct acceptance, raw 64 duplicate acceptance/raw65 refusal, exact Resources ETF65536 acceptance/65537 refusal, and 70 routes sharing one handle.
- Three once-initialized compiled endpoint tests (public/direct/initial-router), plus preparation-once then activation.
- Legacy callback absence plus static empty `%Router{}` without generation ref.
- Dynamic Generation targets retaining `resources: []` across two separately bounded40-handle Stores. Stop each supervised child via stop_supervised!, prove captured PIDs dead, then activate without owner effects. This provides a concrete dead-store traversal counterexample and avoids a false global64 cap.
- A matching unavailable route/sidecar accepted as consistent, then returning the real provider acquisition error and cancellation event.
- Existing generation_validate denied error takes precedence over a raising resources callback. Existing endpoint-validation suite remains the broad hook return/error/order authority.

Every test starts a real active old Store with a real baseline and a request pin acquired by the test PID. Each refusal compares exact old public snapshot and both providers' complete public ledger before/after; any pin/release/cancel operation on either owner is visible. Each test releases its original request pin in a test-process try/after and verifies exact release event and absence of that pin. No production private owner or Store state is read.

Provider uses a mutable test-owned GenServer for ledger only and existing generic public resource APIs. Pins contain provider/owner/operation/ref/handles with optional kind. It intentionally imposes no G/T handle schema and records authenticated holder release. This fixture's lifecycle is controlled by ExUnit; baseline owners outlive Stores during ordered supervisor shutdown.

`initial_start` stops any unexpectedly accepted candidate Store immediately, so an intended RED does not leave a linked candidate running. Expected initial refusal follows Generation's existing cleanup path. No sleeps or unbounded polling; explicit test calls use finite deadlines.

## Intended RED

On the unmodified baseline, root and agreeing-deep-sidecar tests should fail at the public result assertion: expected `{:error, :invalid_endpoint_resources}`, received accepted `{:ok, ...}`. They never invoke the proposed internal validator directly, so missing helper functions cannot masquerade as useful RED. Some compatibility and boundary tests should already pass. Root owns parsing, formatting and actual RED/GREEN execution; no pass or count-executed claim is made here.

## Review notes and limits

Exact ETF padding derives from actual `:erlang.external_size([base])`, uses a binary payload (fixed ETF overhead), and explicitly asserts65536/65537 before checking the contracts. Full Router remains well below1MiB.

Static callback failures that Router.compile already catches are still exercised as forged compiled terms to prove activation recollection, while preparation uses a static Router wrapper so original compilation behavior is preserved.

The two-level tests intentionally compile wrappers around forged inner routers using today's unchanged Router.compile semantics. If an implementation broadens compile to recurse, these tests expose that change at setup; the design explicitly forbids it.

Cumulative inherited counters are not reset: Astra2/2 exhausted; this assignment ran no validation, performed no repair rounds and claims no acceptance. Parent remains responsible for source adoption, command receipts, independent review and final commit.

Memory quick pass: MEMORY.md138-146 only confirmed historical worktree preparation; all current baseline/API facts came from current files. No memory-derived implementation requirement was added.
