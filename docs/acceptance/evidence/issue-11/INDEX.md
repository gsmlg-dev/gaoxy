# Issue 11 and v0.11.1 evidence

Release/tag source: `09715de3f165db134e287e1ea5fd4e93b1325905`.
The later documentation HEAD does not move that tag. See the
[acceptance record](../../release-0.11.1.md) and
[publication receipt](publication-receipt.json) for scope, commands, environments,
counts and preserved limitations.

| Evidence | Scope |
| --- | --- |
| [review.md](review.md) | Independent specification/code review and resolved fixture synchronization findings |
| `issue11-red.*`, `issue11-final-focused.*` | Original failing six-case reproduction and final 38/0 canonical verification |
| `issue11-nearby-*`, `issue11-baseline-*`, `baseline-wss.*` | Failed adjacent attempts and unchanged baseline VM reproductions |
| [local-checks.json](local-checks.json), [qualification.json](qualification.json) | Format/compile/package/gate results and local environment; original failures retained |
| [candidate-manifest.json](candidate-manifest.json) | Hashes of all 428 qualified runtime/test/workflow/manifest/lock source files |
| [static-final.json](static-final.json), [unit-final.json](unit-final.json), [foundation-final.json](foundation-final.json) | Ten successful exact-source prerequisite jobs |
| [unit-first.json](unit-first.json), [unit-failed.log.gz](unit-failed.log.gz) | Initial macOS H2 elapsed-time failure and scheduler witness |
| [dispatch.json](dispatch.json), [release-final.json](release-final.json), [release-final.log.gz](release-final.log.gz) | Exact-SHA publication dispatch; successful complete release workflow, including ordinary 361/0 and standalone smoke |
| [hosted-browser-report.json](hosted-browser-report.json) | Eight H1/H2/H3/browser/WebSocket/reload/shutdown checks, source restored |
| [published-release.json](published-release.json), [published-SHA256SUMS](published-SHA256SUMS), [publication-readback.json](publication-readback.json) | Eight GitHub assets, seven checksum entries, six actual public Hex package checks and exact tag/source readback |
| [public-checks.json](public-checks.json), [public-consumers.log.gz](public-consumers.log.gz), [public-boundary.log.gz](public-boundary.log.gz) | Clean public-package general 7/0 plus issue-specific 6/0, with manual/production/release isolation |
| [public-boundary-mix.exs](public-boundary-mix.exs), [public-boundary-mix.lock](public-boundary-mix.lock) | Exact Hex-only issue consumer inputs; no local dependency override |
| [issue11-final.json](issue11-final.json), [new-issues.json](new-issues.json) | Verified fixed/closed issue and publication comment; later-created #12–14 remain open |
| [SHA256SUMS](SHA256SUMS) | Every evidence file except this checksum manifest |

Original local failed packaging, H3 diagnostic and partial ordinary-gate logs
remain alongside their successful continuations. No failed or unexecuted
assertion is relabeled passing. The Linux binary was not run locally on macOS;
hosted Linux runtime smoke passed.

Logs have deterministic gzip headers. Only ephemeral test-fixture CSRF values
are redacted from the hosted release log and browser report; original raw-file
hashes are in the publication receipt. Original bytes remain in local `.audit`
and the linked hosted run. Downloaded binaries, caches and private fixture keys
are omitted. Archived probe/verification scripts retain their original `.audit`
execution paths and are evidence of those runs.

Routing records use Sol throughout; no Astra escalation or runtime repair round
was needed. `issue11` owns implementation, `issue11_review` is read-only review,
and `release_qualification_diagnosis` is read-only H3 diagnosis.
