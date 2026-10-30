# ARB-VERSION handoff

Status: DONE. Direct Sol assignment; Sol0/Astra0. No repairs or escalations.

Repository: `/home/gao/Workspace/gsmlg-opt/gaoxy`, existing `main`, baseline
`bc8a5ef5199293ada3b432c2e2741070d3b2d115`. Accepted dirty integration existed
before this task and remains preserved. No branch/worktree or Git mutation.

The source advertised 0.13.1 while the parent selected the available 0.14.0
release identity. Seven manifests now contain exactly 0.14.0. Six permitted
READMEs and the separately authorized `docs/phoenix.md` current examples now
use 0.14.0. Their bytes differ from task-start snapshots only in those version
substitutions. Existing adaptive-budget edits are preserved.

`docs/releases/0.14.0.md` contains only the settled user-facing release prose:
shared VM memory admission, threshold behavior, retained ownership/lifetimes,
concurrency quotas, explicit legacy caps, configuration and inspection. It
links to the resource-budget guide and makes no publication, platform or CI
qualification claims. Historical documents, vendor source versions, Phoenix
example version, locks, workflows, generated/build output and other code/tests
were not edited by this task.

Verification: Python exact-byte/version guards PASS; all 7 manifest versions
PASS; all 7 current installation documents PASS; release prose/link guards
PASS; scoped `git diff --check` exit 0. The current Markdown/Elixir-manifest
search for 0.13.1 returned exit 1 with no matches outside intentionally excluded
historical/dependency/build/audit paths. Exact hashes are in `receipt.json`;
`task.patch` is the version-task delta only, separate from pre-existing work.

All task commands are terminal. An overbroad read-only parent-directory `find`
was stopped with Ctrl-C (exit 130), then replaced by the scoped `rg --files`
check. No live task-owned process remains. No Mix/build/network/publication
commands ran. Source ownership and writes are now released to parent.

Parent owns final integrated review, fresh exact-version-source gates and any
authorized commit/push/release. Native-platform/specialist historical NOT RUN
and blocked dispositions are unchanged. No new blocker or decision remains.
