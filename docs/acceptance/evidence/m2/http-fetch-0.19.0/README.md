# HTTP Fetch 0.19.0 M2 retry

The current gate is **INCOMPLETE / BLOCKED_UPSTREAM** on
[http_fetch#64](https://github.com/gsmlg-dev/http_fetch/issues/64). The source
candidate is `597ec0c056cd3ecb4bf1c53e7c99d57691514c2b`; the following documentation
commit adds this record without changing tested code.

- `final-tests-current.log`: 66 core + 110 HTTP + 72 proxy tests, **247 pass and
  1 fails**, exit 2, seed 531954. The only failure loses the present empty query.
- `empty-query-probe.log`: public Fetch string and URI cases both fail target
  preservation, exit 1, while both cleanup receipts return `:ok`.
- `final-compile.log`, `final-format.log`, `actionlint.log`: exit 0. Empty logs
  are normal for successful formatter/linter commands; exit codes are recorded.
- `fixture-tests.log`, `browser-results.json`, `example-results.json`,
  `core-consumer.log`: 2 fixture tests, 13 browser/peer checks, 6 independent
  proxy-example checks and 1 fresh core-only consumer test pass.
- `method-body-probe.log`, `websocket-close-probe.log`: 6 body and 4 Close cases
  pass with the selected published graph.
- `command-results.json`: executed root commands, timestamps, exit codes and
  status. The browser runner creates a separate dev fixture. Worker intermediate
  logs are supporting regression evidence; the full scoped run is authoritative.
- `source-manifest.json`: commit identity and SHA-256 hashes of the tested source,
  tests, fixtures and locks. Markdown documentation is excluded from that snapshot.
- `*-hex.json`, `release*.json`, `package-source-*.json`, `tool-versions.json`:
  package/release identities, byte-for-byte source verification and runtime.
- `otp-receive-bound.md`: exact OTP 28.5.0.5 receive qualification, assumptions and
  ledger exclusions; not qualification of every OTP version or total VM memory.

Historical failed attempts are deliberately preserved. `http-wire-initial.log`
has three empty-query failures plus an invalid response-trailer fixture; that
fixture was separated into valid-trailer and forbidden-trailer tests. The final
empty-query regression remains enabled. `final-tests.log` also finds a test
double missing the new `setopts/2` callback; the final run uses a conforming double
and retains its no-replay assertion. Red/green pairs demonstrate the repaired
downstream deadline, forwarding-trailer and polling-copy bugs. Diagnostic probes
that originally printed a mismatch with exit 0 are not acceptance passes; the
tracked empty-query probe and final wire suite fail explicitly.

No private fixture keys, package source overrides or dependency edits are in this
bundle. Hosted CI, publication and deployment were not run. Earlier 0.17.x and
0.18.1 evidence remains in its original directories.
