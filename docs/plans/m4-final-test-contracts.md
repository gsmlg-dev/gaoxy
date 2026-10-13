# M4 final test-contract implementation plan

Design: [bounded test-contract repair](../designs/m4-final-test-contracts.md).
Worktree: `.trees/m4-http3`, branch `codex/m4-http3`, baseline
`d5831d7613e8c8edd2adf76fbd7b86b408e62de6`, with concurrent root-owned changes.

## Ownership and sequence

The assigned Sol writer owns only
`apps/gaoxy_http3/test/proxy_test.exs`,
`apps/gaoxy_server/test/http3_config_test.exs` and these two new documents.
Other writers own production and acceptance documentation. Preserve their work;
do not run Mix, format, compile or live commands. Root owns all execution,
immutable receipts, cumulative repair accounting and commits.

- [x] Independent SPEC reviewer verifies the three recorded failures, both
  controlled ready branches, unchanged behavioral assertions/deadlines and
  standalone schema/default boundaries. Await root's clearance before tests.
- [x] Recheck the two test files for concurrent changes. In only the held and
  reordered ready branches, replace the opportunistic outer `after wait`
  pending return with original-exchange-deadline waiting and a missing-ready
  barrier exception. Rename the held branch's now-unused `wait` to `_wait`.
  Preserve ordinary fake polling and all existing test assertions exactly.
- [x] Update standalone exact normalized QUIC equality to
  `%{alpn: ["h3"], poll_interval: 10}`. Add a rejection-table input
  `{"quic", %{"alpn" => ["h3"], "poll_interval" => 1}}`, retaining the
  existing rejection and owner-absence assertions. No schema edit.
- [x] Root runs both complete owned test files, checks exact authored-file
  formatting with canonical Elixir1.18.5 and strict compilation, and records
  actual counts/exits/source hashes. Preserve existing527/3 FAIL as RED.
- [x] Independent CODE/evidence review confirms the fixture barriers truly
  control ready, all original behavioral/origin/cleanup assertions remain,
  external polling is rejected and exact default10 remains. Resolve actionable
  findings in the same narrow ownership; root executes fresh affected tests.
- [x] Root runs fresh prescribed final M4 source/native/browser/standalone/
  Session/consumer verification separately. Neither focused PASS nor this
  test-contract repair qualifies the independent upstream matrix or release.

## Root-owned focused command

```sh
nix develop --command env MIX_ENV=test ERL_FLAGS='+S 2:2' python scripts/check-tests.py apps/gaoxy_http3/test/proxy_test.exs apps/gaoxy_server/test/http3_config_test.exs
```

The existing final-source series command and all other required final M4 gates
remain root-owned. Tests/format/compile were **NOT RUN by the implementation writer**. Root's
[focused44/0](../acceptance/evidence/m4/upstream-matrix/final-test-contract-green-1791855566615515224.json)
and [final source530/0](../acceptance/evidence/m4/upstream-matrix/final-source-repair12-1791855605032421223.json)
PASS. The [whole-candidate SPEC/CODE review](../acceptance/evidence/m4/upstream-matrix/review-m4-final-source-spec-code-preparation-1791856541203317954.json)
clears source preparation; [all prescribed final implementation executions](../acceptance/m4.md#final-implementation-gate-ledger--2026-10-13)
PASS. Final independent actual-evidence/documentation acceptance PASS.

- [x] Complete final independent M4 acceptance before release eligibility.

Planning adds zero repair rounds; root carries existing unsuccessful counts and records
the next bounded repair outcome without resetting any Sol/Astra ledger.

Final M4 implementation acceptance: [independent review](../acceptance/evidence/m4/upstream-matrix/review-m4-final-implementation-candidate-acceptance-1791858009332797257.json),
PASS with no unresolved findings. Portable qualification/publication stay separate.
