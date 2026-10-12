# Independent clean H1/H2 consumer review

Reviewer `/root/m4_spec_review`, independent from parent author, read-only
2026-10-12 in `.trees/m4-http3`, branch `codex/m4-http3`, HEAD `2b4a5e5`,
starting baseline `78de9d0`.

## Specification compliance: PASS

Reviewed the four consumer/script files below and
`isolation-early/http-repair1.json` plus its raw log. The fresh completely
separate temporary project executed **2 tests, 0 failures**, exit0 after locked
dependency resolution and warnings-as-errors compilation/tests. Every recorded
input hash and raw-log hash matched the current files when reviewed. This review
does not claim rerunning the author-owned 109.64-second rebuild.

The consumer resolves/starts `gaoxy_http` and asserts absence of gaoxy_http3,
elixir_quic, elixir_quic_http3, ex_ssl, http_fetch and bandit from resolved and
running apps, code lookup and installed dependency directories. It then exchanges
actual loopback native H1 and H2 requests using public Gaoxy service APIs and
asserts status200 plus exact response body `consumer`. Separate listeners follow
the supported H1 and H2-prior-knowledge configuration contracts. Shutdown and
owned temporary directory cleanup remain bounded. Root lock/source did not change
through this gate. No unresolved specification findings remain.

## Code quality: PASS

Initial failures are preserved in `isolation-early/http.log`: the fixture called
nonexistent Mix.Dep.load_on_environment/1 and requested an unsupported mixed
h2c configuration. The repair uses the verified installed public
Mix.Dep.load_and_cache/0, selects separate H1 and H2 listeners, and supplies the
existing H2 reservation budget. It strengthens socket-receive pattern assertions
and avoids double shutdown in cleanup without changing product behavior or
removing isolation/native-wire checks. The script copies only necessary source
and vendor adapter into a fresh temporary tree, reuses the locked dependency
cohort and deletes only its own temp directory. No implementation workaround,
new dependency, private runtime introspection, publication or unrelated cleanup
was introduced. No unresolved code-quality findings remain.

This qualifies only clean core/H1/H2 optional-package isolation and native
H1/H2 consumer exchange. H3 clean consumer and all M4 live/shared/browser/upstream
acceptance remain separate. Original FAIL and fresh PASS stay separately visible.
Parent owns commits. Reviewer commands finished; no process is owned here.

## Reviewed owned input hashes

- `integration/http_consumer/mix.exs`: `4e54c9d3996ab1ada45d60da98c5271c9a0df3bee0d5ba786caf709c14a50147`
- `integration/http_consumer/test/test_helper.exs`: `b086ec47f0c6c7aaeb4cffca5ae5243dd05e0dc96ab761ced93325d5315f4b12`
- `integration/http_consumer/test/consumer_test.exs`: `125b6d94a3f9170f847bc3fcfe32c93d4885bc87b56d2ccc522b0a5a9ca34c61`
- `scripts/http-consumer.sh`: `16633262966d02229f37aa364c3f75fd8085fb1880d60ab5dbc96774bf9f9c0b`
