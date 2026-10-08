# M1.1 execution evidence

The [acceptance record](../../../m1-1-hardening-acceptance.md) identifies the
candidate, exact commands, selected counts, environments and limitations.

- `candidate-source.json`: 86 production, test, configuration, workflow and
  lockfile SHA-256 values, verified against commit `8ae2b6d` and the final local
  formatter/full-suite before/after snapshots. It also identifies the acceptance
  test, peer and harness changes since the first implementation commit.
- `ci-merge-commit.json`: GitHub synthetic-merge identity and tree, identical to
  the tested candidate tree.
- `ci-final-evidence.json`: all five final-candidate workflows and 16 jobs
  passed; includes every job/step conclusion, exact counts, runtime versions,
  source comparisons, numbered log excerpts and raw-log hashes.
- `ci-initial-evidence.json`: complete first-candidate run/job/step conclusions
  and numbered log excerpts. Its failures are retained; they do not establish
  the final candidate's acceptance. `ci-second-evidence.json`,
  `ci-third-evidence.json` and `ci-fourth-evidence.json` retain later failures,
  skipped steps and the fourth candidate's cancelled push macOS release.
- `local-full-suite.log`, `local-quic-tests.log` and
  `local-formatter-idempotence.log`: final tests and formatting after the
  deterministic CI fixture repairs. `local-harness-regressions.log` records
  the eight counter and five release-harness regression results.
- Other `local-*` execution logs: network/release/consumer checks on unchanged
  production/script/lock inputs. Final-candidate hosted jobs repeat those gates.
- `baseline-*`, `intermediate-*`, `quic-fixture-role-red.log`,
  `release-harness-regressions-red.log` and `network-*-parallel-failure.log`:
  diagnostic and failure history, not passing
  final-candidate gates. The early lifecycle red log includes a TLS ALPN setup
  failure which is not counted as a reproduced shutdown failure.
- `udp-reuse-diagnostic.md` and `endpoint-readiness-reproduction.md`: controlled
  diagnoses, preserved uncertainty about the historical CI failure, and the
  resulting focused test repairs.

Local logs retain the original output with trailing whitespace normalized.
`evidence-index.json` records stored artifact hashes and original log hashes.
No private keys or fixture credentials are included. Hosted full logs remain
available at the job URLs recorded in the CI metadata; excerpts retain line
numbers and raw-log hashes.
