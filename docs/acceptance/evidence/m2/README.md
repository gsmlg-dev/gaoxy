# Local native M2 evidence

This bundle records the locally tested native deliverable on `codex/m2-native`.
Full M2 remains blocked on HTTP Fetch #27–#30; hosted M2 CI has not run.

- `source-manifest.json` identifies the executable commit and hashes its scoped inputs.
- `command-results.json` records invocations and collected exit codes; the intentionally failing review reproduction is marked separately.
- `final-tests.log`: 45 core and 82 HTTP tests, zero failures.
- `fixture-tests.log`: 2 real Phoenix ownership tests, zero failures.
- `core-consumer.log`: a fresh standalone core consumer, strict compile and 1 test.
- `browser-results.json`: 13 successful independent-peer/browser checks, with runner exit 0 recorded in `command-results.json`.
- `browser-server.log` preserves server output with CSRF token values filtered. The screenshot is supporting evidence; the runner assertions establish results.
- `vendor-verification.json`: vendored hashes, exact fork parent and exact commit patch verified; `vendor-test.log` records the isolated dispatch regression.
- `upstream-issues.json` is a timestamped issue-state snapshot, not dependency acceptance.

The core consumer log omits dependency-fetch progress and trims trailing whitespace;
the original output remains in the local audit directory. Tool versions and the
immutable dependency locks are recorded. Certificate/private
key files, virtual environments, dependency/build directories and temporary upload
files are excluded. `evidence-index.json` hashes all files in this bundle except
itself. See [the gate record](../../m2.md) for scope and remaining work.
