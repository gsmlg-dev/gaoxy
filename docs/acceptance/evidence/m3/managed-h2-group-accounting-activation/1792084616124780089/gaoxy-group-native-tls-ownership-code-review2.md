# Native TLS ownership proposal2 — focused code review

**DONE_REVIEW_NO_OPEN_SOURCE_FINDINGS.** Task `/root/browser_contract_spec/native-tls-ownership-code-review2`; direct independent read-only CODE review. This closes the two prior findings at source-review level. It does not accept an implemented repair or the stage: proposal2 remains unadopted, with zero newly executed tests.

Worktree: `/home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-h1-resource-foundation`. Historical supplied baseline: `7cff6e87edb9b67e2667897bfbb7ee7e0075162e`. No Git was run. Current existing target hashes match the declared original bytes, and the new test file is absent. No whole-tree source identity is asserted.

The complete proposal2 patch SHA256 is `a02084cbf31ae9ccff7b8028ec9c5de2f70f4a29dd502b168cefcf7ef15ebd2c`. It replaces proposal1 against its original before bytes; it is not incremental. A read-only Python stdlib reconstruction checked both patches in memory, all context lines and hunk counts, every declared before/after hash and new-file absence. All passed (exit0). Production and accounting targets are byte-identical between proposals, and all three proposal1 artifacts retain their declared hashes.

## Finding dispositions

- **TLS-CODE-01 — CLOSED_AT_SOURCE_REVIEW.** Proposal2 patch250–254 adds precisely `{:shutdown, :peer_closed}` only for the native owner. Other actor reasons, real monitors and finite join deadlines remain unchanged. This matches ThousandIsland.Handler421's ssl_closed return.
- **TLS-SPEC-01 — CLOSED_AT_SOURCE_REVIEW.** Proposal2 patch267–418 adds a real verified TLS/h2 request endpoint using the original worker, stream1, token, lease and actual GenServer From. Only its local Exchange deadline is extended. Only the native owner is suspended. The actual ordinary Transport.operation is observed queued before the original authoritative deadline; the original Admission watchdog remains live and its exact expired lease/token callback and killed worker are observed. The same owner's original worker DOWN must be queued after the call. Resuming the owner therefore exercises authorization with its original stream record before DOWN removal and requires both exact GenServer.reply and underlying gen.reply timeout calls to the original From. A live local deadline prevents the caller-side timeout guard from satisfying the test. The dead caller's alias is not used as a fabricated recipient.

The owner/gate trace-delivered fences and exact empty remaining reply list reject extra replies to that From. Real worker/owner/Writer/Service/gate joins, removed lease, empty cleanup state, zero native service ledger and unchanged G.clean/G.close preserve cleanup and accounting assertions. The physically joined independent peer must report only the earlier health request. No synthetic call/From, state mutation, manual worker kill, Admission suspension or timer disable is introduced. Mailbox, monitor and trace barriers use finite deadlines. try/after and on_exit restore the test's owner/tracing on failure.

## Production and verification limits

No new production defect was identified. The original caller-worker/id/token authority precedes the new original stream.deadline check. Full SSL metadata stays on the existing native owner while stream Exchange.ssl becomes nil. Native H1 and H3/other getter paths are unchanged. Copied foreign-worker Exchanges return nil/closed under the previously authorized boundary. No accountant or cap is relaxed.

Source crosschecks included Admission365–369, Connection571–580 and1107–1123, Transport16–34, fixture eventually629–645, G.clean299–319/G.close364–399 and ThousandIsland.Handler421. All report/reconstruction commands completed. No repository writes, Git, build, runtime, browser, or actor manipulation occurred. Only this new review pair was written.

The 405-line proposed test remains unformatted, uncompiled and unexecuted. Exact loaded-VM tracing and all physical joins require actual execution; source review does not prove RED/GREEN sensitivity or native H1/H2/H3, group/Session or browser acceptance. Those remain parent-owned gates. Latest parent-only status was startup50/0 PASS, live110/0 PASS, Session46/4 FAIL pending diagnosis; proposal2 was not adopted and is not assigned as that failure's cause.

Reviewer repair rounds added0; last supplied cumulative parent counters failedGREEN18/rootrepair20, separate diagnostic failure1, Astra2/2 exhausted. No counters reset. `UNCONFIRMED_WITH_RETAINED_FAILURE` remains the historical negative TLS disposition. No decision or scope expansion is requested.
