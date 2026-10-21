# Mix dependency refresh acceptance — 2026-10-21

Base: `0a0f9d195db688719d9000abc1bb4915341c61d5`. Development is directly on
`main`; Gaoxy remains version `0.5.5`. This record covers local dependency
qualification. No new push, tag, package publication or deployment was performed.

## Resolved versions and package boundary

`mix hex.outdated --all` identified seven outdated root dependencies blocked by
exact requirements. Normal `mix deps.update --all` resolution refreshed all
three tracked lockfiles after updating the relevant manifests:

| Dependency / scope | Previous | Result |
|---|---|---|
| `elixir_quic`, `elixir_quic_http3`, `ex_ssl`, `http_core`, `http_fetch`, `http_runtime`, `http_web_socket` in the umbrella | `0.21.10` | `0.21.14` |
| Independent QUIC consumer's `elixir_quic` / `ex_ssl` | `0.21.4` | `0.21.14` |
| Phoenix example's `phoenix` | `1.8.15` | `1.8.16` |
| Phoenix example's `phoenix_live_view` | `1.2.12` | `1.2.13` |

The H3 consumer and Phoenix example resolve the same shared HTTP/TLS/QUIC
versions. All other lock entries remain unchanged. The final outdated audits
in the umbrella, QUIC consumer and Phoenix example each **PASS**, exit 0;
every active Hex dependency is at its latest stable release at verification time.
Hell retains its `0.1.2` source pin
`59eed42b019ca41413d1b8cd7a7dc3e344bb93ee`; Git/path dependencies are outside
the Hex outdated audit.

All seven HTTP cohort Hex versions are published and unretired, share
[upstream release v0.21.14](https://github.com/gsmlg-dev/http_fetch/releases/tag/v0.21.14),
and require exact `0.21.14` internal cohort dependencies. Its tag resolves to
`6b69bde3f43f2270317c38fbe68d5ac9635d3b36`, whose seven package manifests
declare that version. This verifies published metadata and the shared source/tag;
it does not establish a tarball-to-Git-blob comparison.

Hex `abyss == 0.9.0` remains unchanged. The effective root dependency graph and
all three locks contain neither `abyss_raw` nor Rustler. Scanning the 22 fresh
root dependency checkouts found no Rust/Cargo/native-library files or NIF loaders.
The optional raw compatibility facade in Abyss remains Elixir-only and reports
the missing optional dependency. OTP/ERTS and OTP `crypto`/OpenSSL retain their
own native components; Python peer libraries are external verification tools.

Package-staging regression expectations now require the actual `0.21.14`
manifests. The existing staging tool generates those requirements without a
special translation. Nine packaging tests **PASS**, including building all five
real Hex tarballs with test fixture version `9.8.7` and inspecting their metadata
and unchanged source payloads. This is local packaging verification.

## Executed verification

Environment: Linux x86_64, installed Elixir `1.18.5`, OTP `28`, ERTS
`16.4.0.5`, `ELIXIR_ERL_OPTIONS='+S 2:2'`. Independent Python peers use h2
`4.3.0`, hpack `4.2.0`, hyperframe `6.1.0` and aioquic `1.2.0`.
Mix commands use `unbuffer`. Repair wrappers select `MIX_ENV=test`.

Command, cwd, environment, exit, timing and raw output receipts are preserved
under `.audit/dependency-upgrade/20261021T044833Z-449fc25f/`; table labels name
the corresponding `.json` / `.log` pair.

| Receipt / command or scope | Result |
|---|---|
| `resolve-{root,quic,phoenix}`: `mix deps.update --all` | PASS, exit 0 each |
| `fetch-root-clean`: fresh `mix deps.get --check-locked` | PASS, exit 0 |
| `outdated-{root,quic,phoenix}-after`: `mix hex.outdated --all` | PASS, exit 0 each |
| `format`: `mix format --check-formatted` | PASS, exit 0 |
| `compile-root-test-isolated`, `compile-root-prod`: fresh `mix compile --warnings-as-errors` | PASS, exit 0 each |
| `compile-quic`, `compile-phoenix`: strict compile; Phoenix H3 enabled | PASS, exit 0 each |
| `repair-all`: `python3 scripts/check-repairs.py all` | PASS, 160 executed, 0 failures/excluded/skipped, exit 0 |
| `test-core-focused`: certificate fixture, TLS, datagram egress and backend telemetry via `scripts/check-tests.py`, seed 0 / max-cases 1 | PASS, 8 tests, 0 failures, exit 0 |
| `test-quic`: independent QUIC consumer through `scripts/check-tests.py` | PASS, 4 tests with independent validating peer, 0 failures, exit 0 |
| `test-phoenix`: example `mix test --warnings-as-errors --seed 0`, `PHOENIX_NATIVE_H3=1` | PASS, 5 tests, 0 failures, exit 0 |
| `consumer-core`, `consumer-http`, `consumer-h3`: existing consumer shell gates with fresh external source/deps/build | PASS, 1 / 3 / 2 tests, 0 failures, exit 0 each |
| `test-check-tests`, `test-check-repairs`: Python wrapper regressions | PASS, 8 / 6 tests, exit 0 each |
| `test-release-smoke`: release-smoke script unit tests | PASS, 5 tests, exit 0 |
| `test-stage-packages`: real package metadata/payload regressions | PASS, 9 tests, exit 0 |
| `graph-root`: `mix deps.tree`; `dependency-boundary.json` | PASS, exit 0; retained native boundary verified |

Final runtime/regression executions total **183**, plus **28** script/package
tests, with no failures. This is scoped ordinary qualification; specialist
disconnect, blocked-upload, pressure and sustained-load slices remain excluded
by the current acceptance scope. Hosted CI and new standalone release builds/
runtime smokes were **NOT RUN** for this refresh.

Initial QUIC/Phoenix outdated probes **FAILED**, exit 1, before dependencies
were fetched; their final resolved audits pass. The first root test compile
also **FAILED**, exit 1, with five outdated-build markers. Independent diagnosis
found Mix `1.18.5` fetch finalization invalidates markers beneath the parent of
the configured build path; the concurrent Phoenix fetch and marker timestamps
support a collision between sibling custom build directories. Deletion syscalls
were not traced. Fresh root test/production builds under `root-build/{test,prod}`
and Phoenix test under `phoenix-build/test` pass after using separate project
build parents. No application change or assertion relaxation was needed.
The failed compile receipt remains preserved, together with
`compile-diagnosis.json` (SHA-256
`2638c961449b24dc1a5030cf06bb1a52b377b58e6aa15c80ea031bdd334a229e`).
A separate diagnostic probe failed because it called an unavailable Mix API;
that probe is retained as `diagnose-root-deps`, exit 1.

Source review passed before the fresh root compile and ordinary regression
gate. Final documentation/receipt review and commit checks are recorded in the
same audit directory. The unrelated untracked `gaoxy-codex-repair-plan.md`
retains SHA-256
`21ee6eb463743c78571e5e2c7ea7de643e208b2a6ef545df187873dcc960bb5b`.
