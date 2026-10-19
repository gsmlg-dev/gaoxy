# Hell migration acceptance — 2026-10-19

**Status: PASS; implementation committed and integrated into local main.** Independent public-API, specification and final code reviews pass.
Results below were executed against Hell; earlier Thousand Island evidence is
retained separately.

## Migration design

The [migration plan](../plans/hell-migration.md) replaces Thousand Island with
[gsmlg-dev/hell](https://github.com/gsmlg-dev/hell), pinned to
`59eed42b019ca41413d1b8cd7a7dc3e344bb93ee` (declared version **0.1.2**, MIT).
The dependency and OTP application are `:hell`; listener lifecycle, handlers,
sockets and transport adapters use the public `Hell.*` APIs directly. Native
handlers implement `Hell.Handler`. There is no old-namespace compatibility shim;
Hell's own telemetry uses the `:hell` prefix.

Gaoxy retains listener ownership, admission, strict socket accounting, lifecycle
barriers and existing HTTP/protocol defaults. Live source and fixtures migrate
together with the root, Phoenix example and QUIC consumer locks. Abyss and the
HTTP/QUIC dependency cohort remain unchanged. No dependency source is patched.
The [dependency audit](../dependency-audit.md) separates this current backend
from historical source identities.

## Verification ledger

[Evidence summary](evidence/hell-migration/verification-summary.json) and
[archive manifest](evidence/hell-migration/manifest-verification.json) bind the
commands, exits, source/diff/lock identities, output hashes and actual counts.
[Integration archive](evidence/hell-migration/manifest-integrated.json) adds
the exact main-checkout receipts. Logs and browser netlogs are lossless gzip; original failed attempts
are preserved alongside their successful fresh executions.

| Gate | Actual status | Evidence |
| --- | --- | --- |
| Public API audit | PASS, static; no public API blocker | [audit](evidence/hell-migration/api-audit.json) |
| Independent specification review | PASS | [review](evidence/hell-migration/spec-review.json) |
| Independent final code review | PASS, 49 reviewed file hashes; documentation finding resolved | [review](evidence/hell-migration/code-review-final.json) |
| Unchanged-backend baseline | PASS: 7 executed, 0 failures, 40 excluded | [baseline](evidence/hell-migration/baseline.json) |
| Targeted formatting and production compilation | PASS: 38 changed Elixir files; production warnings treated as errors | [format](evidence/hell-migration/format-check.json), [compile](evidence/hell-migration/compile-prod.json) |
| Added ordinary native TCP/TLS/HTTP/relay regression | PASS: 10 executed, 0 failures, 54 excluded | [fresh native](evidence/hell-migration/hell-native-ordinary-fresh.json) |
| Accepted M5 ordinary compatibility selection | PASS: 138 executed, 0 failures | [M5](evidence/hell-migration/m5-ordinary.json) |
| Accepted M3 ordinary unit/network selection | PASS: 38 + 24 executed, 0 failures, 90 network exclusions | [unit](evidence/hell-migration/m3-ordinary-unit.json), [network](evidence/hell-migration/m3-ordinary-network.json) |
| Independent native H2 and h2c WebSocket peers | PASS: 15/15 each, normal close and fixture shutdown | [H2](evidence/hell-migration/peer-h2/run-1792417674636140842/report.json), [h2c](evidence/hell-migration/peer-h2c/run-1792417679534853449/report.json) |
| Isolated core and HTTP consumers | PASS: 1 + 2 real network tests; Hell resolved/started, old application absent, optional-app isolation preserved | [core](evidence/hell-migration/consumer-core-fresh.json), [HTTP](evidence/hell-migration/consumer-http.json) |
| Phoenix example locked resolution and strict compilation | PASS with `MIX_ENV=dev PHOENIX_NATIVE_H3=1` | [resolution](evidence/hell-migration/phoenix-deps.json), [compile](evidence/hell-migration/phoenix-compile.json) |
| Phoenix H2 and H1 browser profiles | PASS: 12/12 each; native wire correlation, Channel/LiveView, admission release and fixture shutdown | [H2](evidence/hell-migration/browser-h2/run-1792417685101699371/report.json), [H1](evidence/hell-migration/browser-http1/run-1792417709802278565/report.json) |
| Fresh affected verification following final code review | PASS: ordinary suites, isolated consumers and peers/browser against unchanged reviewed functional source | [source snapshot](evidence/hell-migration/verified-source.json), [summary](evidence/hell-migration/verification-summary.json) |
| Local commit and local-main integration | PASS: implementation `b93ee72` fast-forwarded into main; 10 fresh ordinary executions, 0 failures, 54 excluded; strict dev/test/prod compilation and Hell metadata verified | [integration](evidence/hell-migration/main-integration.json), [main tests](evidence/hell-migration/main-ordinary.json) |

The four ordinary regression batches total **210 executions / 0 failures**;
isolated consumers add 3 executions. Independent peers and browsers record 30
and 24 case checks separately. Counts are not a unique-test claim. No executed
case was skipped. The baseline's plain-file TLS argument was excluded by line
filtering; the migrated native batch explicitly selects `tls_test.exs:12` and
executes it.

The final functional snapshot is base
`a93baedae3a3b86fba267dc5fd22b7fe041b24d0` plus
[`verified.diff.gz`](evidence/hell-migration/verified.diff.gz), whose uncompressed
SHA256 is
`405c3e457f6f821f41742481f1691839a4285f7ec4e987796ca61066b63ee6ce`.
The source manifest records 429 live source/config/test/script/lock files.
Subsequent acceptance/documentation updates do not change those files.

Root, Phoenix example and QUIC consumer lock SHA256 values respectively are
`9f04f56f7b3389e217803614537133cda21a6bc176d2499fdcee6128292f0777`,
`7059476a6e745020b89f610a54bd908d2c26181e88cac3ee511d61390f8bfda1` and
`29f94cbaa63d9f2264e61b5808d0280b479a56b2a26c39e2ff8e5aeccfcce990`.
Each lock changes only Thousand Island to the exact Hell pin.

[Environment](evidence/hell-migration/environment.json): Elixir 1.18.5,
OTP 28 / ERTS 16.4.0.6, Python 3.13.15, h2 4.3.0, wsproto 1.2.0,
aioquic 1.2.0, Playwright 1.56.0 and Chromium 152.0.7977.64. Leading `env`
arguments in command receipts supply effective production/Phoenix environment
overrides; the wrapper environment is also retained. Network/build operations
were serialized. [Verified local Git caches](evidence/hell-migration/cache-route-v2.json)
avoid redundant dependency asset transfers through process-local URL rewrites;
canonical manifests/locks and global Git configuration remain unchanged.

[Diagnosis](evidence/hell-migration/diagnosis.json) preserves three unsuccessful
setup/startup attempts, all with zero executed tests: interrupted network fetch,
initial old application metadata in the baseline build cache, and a detached
Abyss cache without a fetchable branch. Their final resolution, fresh dependency
inspection and successful executions remain separate evidence. No product
source workaround, dependency patch, weakened assertion or new Astra recovery
was introduced; inherited Astra usage remains 2/2.

## Ordinary verification boundary

Only finite ordinary scenarios are in scope. The accepted ordinary compatibility
selection and positive TCP/TLS, HTTP/H2/h2c/WebSocket and Phoenix browser flows
retain their assertions and finite deadlines. Browser acceptance requires
correlation with the native WebSocket transport, normal Close, admission release
and owned fixture shutdown. Isolated consumers must establish that Hell is
resolved/started, Thousand Island is absent and optional applications remain
outside the core dependency graph.

Dedicated abnormal/disconnect, slow-peer, pressure, sustained-load and soak
qualification remains **NOT RUN here**, assigned to its specialist environment.
Do not run entire mixed-scope test files when that would execute excluded cases.
Historical failed, blocked and unexecuted results retain their actual status;
assertions and evidence are preserved. The excluded `http_fetch#97` proof is not
an acceptance requirement or blocker.

## Local source and published release boundary

Implementation commit `b93ee724c51ac928408896bcdc7294e8e96bd1db` carries
`[skip ci]` and was fast-forwarded into local `main` after independent review.
[Integration evidence](evidence/hell-migration/main-integration.json) binds its
exact source identity, another 10 ordinary network executions, strict compilation
in dev/test/prod, refreshed Hell application metadata and preservation of the
unrelated untracked `gaoxy-m1.1-fix-prompt.md`. All 429 verified functional files
match in main. Documentation closeout preserves that functional snapshot.
No push, new release, package/image publication or deployment is included.

Published [v0.4.0](https://github.com/gsmlg-opt/gaoxy/releases/tag/v0.4.0) remains
at `ebd2b12a997750109ffd3fc7db4f3eda223ab79b` and retains Thousand Island.
Its source, assets, release recipes, acceptance reports and verification counts
remain immutable historical evidence; they do not certify Hell. Operational
certificates, production data, Vault, public management and the disabled
release-artifact E2E workflow remain outside this task.
