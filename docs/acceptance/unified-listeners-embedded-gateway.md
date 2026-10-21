# Unified listeners and embedded Gateway acceptance

Date: 2026-10-22, Asia/Shanghai. Specification: Agent Note
`c676efd4-a6a5-4157-879b-750f1563c0d2`, revision 1, preserved in the
[design](../designs/unified-listeners-embedded-gateway.md). The
[plan](../plans/unified-listeners-embedded-gateway.md) tracks completion.
Implementation starts at `656dbf5bb84564adc6a4d68247c0ad2fe52c2625`, preserving
the released mixed cleartext H1/prior-knowledge H2 behavior and prior evidence.
Work is isolated in `.trees/unified-gateway` on `codex/unified-gateway`.
Local implementation commits: core `7e45d7e1`, HTTP `bc66c489`, and Gateway /
standalone `52a96976`; coordinated 0.8.0 qualification `14c5fd91`; and
Elixir 1.20 compiler compatibility `d206e55de1696a8801a1cd64d80c7b903671641a`.
Integration and publication receipts are recorded after their actual completion.

Status: implementation, ordinary verification, independent source review and
coordinated 0.8.0 publication PASS. Public package consumers and the downloaded
standalone runtime PASS. Deployment is NOT RUN and remains outside this task.

## Delivered contracts

`Gaoxy.HTTP.ListenerSet` separates stable pure Plans from bounded runtime
preparation. H1/H2 and optional H3 providers share one prepared application
target, with protocol-specific service budgets. Core staged activation uses the
complete planned services, retains their shutdown ceiling and owns late startup
and rollback. Core has no HTTP dependency; HTTP has no Proxy/Server dependency
or reverse H3 Mix dependency.

`Gaoxy.PhoenixAdapter` creates one ListenerSet owner and one core instance per
Endpoint. Explicit `http3:` configuration shares the Endpoint, reload wrapping
and exact WebSocket paths. `server_info/2` preserves HTTP/HTTPS compatibility;
transport inspection reports actual addresses and degraded state. The adapter
child's PID identifies its ListenerSet owner; `ListenerSet.info(owner).instance`
returns the core instance for generic core inspection. Existing core instance
registration is retained.

`Gaoxy.Proxy.Gateway` owns namespaced stable stores and a restartable runtime
group. Each explicit set shares an authoritative route store across its physical
listeners. Accepted declaration/revision, runtime epoch, active Router/baseline
and operation receipt commit together. Recovery materializes the latest accepted
routes and immutable upstream trust in a new epoch. Caller loss or a late reply
does not relinquish cleanup or make an unknown outcome a rejection. Stop
serializes draining barriers and keeps upstream cleanup owners alive while the
core drains. Standalone JSON v1 and file reload delegate to this implementation;
legacy independent services are not implicitly grouped.

Opt-in Alt-Svc discovery observes committed activation and current listener
readiness before secure H1/H2 final response-header budget validation. It covers
native, Plug and proxied responses, including streaming/file starts. It replaces
conflicting upstream/application values only when discovery is enabled.

Public configuration, inspection and reload examples are in
[Phoenix](../phoenix.md), [ListenerSets](../listener-sets.md) and
[embedded Gateway](../embedded-gateway.md). Coordinated package/release version:
**0.8.0**. Vendored upstream source version and provenance are unchanged.

## Verification

Local environment: Elixir 1.18.5, OTP 28, `ELIXIR_ERL_OPTIONS='+S 4:4'`.
Independent TLS H1/H2 and aioquic 1.2.0 peers use the pinned `.audit/h2peer`
environment. Browser verification uses Chromium through Playwright. Root Mix
operations serialize through `.audit/mix.lock`; external consumers use separate
temporary projects, dependency resolution and builds. Counts for separate runs
overlap and must not be added as unique cases.

| Gate | Actual result |
| --- | --- |
| Core staged activation and existing lifecycle compatibility | PASS: 51 tests, 0 failures |
| HTTP/H3 listener composition and discovery | PASS: final HTTP 10 + mixed network 7 + H3 network 8 = 25 tests, 0 failures |
| Gateway, Generation and standalone compatibility | PASS: 30 tests, 0 failures (Generation 3, Gateway 7, standalone 20) |
| Gateway public lifecycle/deadline/reconciliation | PASS: 20 tests, 0 failures (Gateway 7, lifecycle 13) |
| Exact ordinary compatibility and composition gate | PASS: 265 executed, 0 failures, 0 excluded, 0 skipped; prior failures retained |
| External core consumer | PASS: strict compilation; 1 test, 0 failures; optional HTTP/QUIC dependencies absent |
| External HTTP consumer without Proxy/H3 | PASS: strict compilation; 4 tests, 0 failures; explicit missing H3 rejection |
| External Gateway consumer without Server/H3 | PASS: strict compilation; 1 test, 0 failures; managed traffic, reload, stop |
| External optional H3 Gateway consumer without Server | PASS: strict compilation; 1 test, 0 failures; real H1/H2/H3 traffic, reload and released TCP/UDP bindings |
| Phoenix example | PASS: 5 tests, 0 failures |
| Actual unified Phoenix browser and independent peers | PASS: 8 checks; forced H1/H2/H3, exact native H2/H3 WebSockets, LiveView/Channel, code reload/restoration, clean Endpoint exit |
| Canonical formatting and strict production compilation | PASS after final lifecycle repair: formatter and strict production compile exit 0 |
| Production release assembly and smoke | PASS: core 3 transports, Gateway 7 exchanges (5 mixed), H3 3 checks; all processes exit 0 |
| Packaging regression harness | PASS: 9 tests, 0 failures |
| Gate-counter and release-smoke harness regressions | PASS: 6 and 5 tests respectively |
| Coordinated five package archives | PASS: five actual 0.8.0 archives; all 122 runtime payload files match staged source |
| Independent specification and code reviews | PASS: core, HTTP, Gateway/Generation/standalone/accounting and final shutdown/preflight followup; no remaining code findings |
| Integration and hosted CI | PR [#4](https://github.com/gsmlg-dev/gaoxy/pull/4) merged normally into main `2539b3c4`; all corrected-source PR workflows PASS. Final main Unit (180/0 per platform), Static and Foundation PASS on `0f8b7775`; historical macOS failures preserved below |
| Coordinated publication | PASS: GitHub `v0.8.0` and five Hex distributions; exact tag/source, assets, checksums and payloads independently verified |
| Public Hex consumers | PASS: 11 tests across four isolated projects, 0 failures/exclusions/skips; public archives only |
| Downloaded public runtime | PASS: core 3, Gateway 7 and H3 3 checks; all five own application versions verified as 0.8.0 |
| Deployment/production acceptance | NOT RUN; outside this task |

Acceptance matrix evidence maps to these scoped suites and real peers:

| Specification rows | Direct coverage |
| --- | --- |
| A01, A02, A03, B01 | Pure ListenerSet/Gateway declaration tests, external core/HTTP/Gateway consumers, dependency and source cross-review |
| A04, A05, A06 | `staged_activation_test.exs`: complete budgets, validation before bind, occupied port rollback, deadline/caller loss and continued cleanup |
| H01, H07 | Actual unified Phoenix gate plus `listener_set_network_test.exs`; forced negotiated versions and exact `/live/websocket` and `/socket/websocket` CONNECT paths |
| H02, H06 | Protocol-default/Phoenix ownership tests, mixed native network test, Endpoint stop/restart and duplicate-mount protection |
| H03, H04, H08 | Nonzero TCP/UDP same port, independent actual ephemeral ports, occupied UDP rollback and current-incarnation inspection tests |
| H05 | Missing provider external consumer; direct invalid-credential, unsupported-bind and target-init failure tests verify structured errors, absent runtime and reusable bindings |
| D01, D02 | ListenerSet network native/Plug/file/stream responses, managed Gateway peer, current H3 incarnation suppression and renderer budget assertions |
| G01, G02 | Two isolated external Gateway projects and two-Gateway isolation test |
| G03 | Shared H1/H2/H3 managed-route reload and an old held in-flight request completing its prior snapshot |
| G04, G05 | Failed/stale/expired candidate tests retain accepted revision and active body; immutable trust preparation errors |
| G06, G07 | Discarded commit reply, receipt reconciliation/eviction, caller death during owned preparation and identity-conflict rejection |
| G08, G12 | Accepted managed routes/trust after owner recovery, next reload success; old-epoch commit rejection at unchanged revision |
| G09, G10, G11 | Busy preparation reports unknown cleanup, pending-pin reconciliation, stop barriers against late preparation/readiness and continued stop after caller timeout |
| S01, S02 | Standalone config/routes/resources/H3 generation/recovery tests and actual packaged startup/readiness/traffic/stop |

Principal commands, run from the implementation worktree:

```sh
ELIXIR_ERL_OPTIONS='+S 4:4' flock .audit/mix.lock \
  python3 scripts/check-repairs.py all
ELIXIR_ERL_OPTIONS='+S 4:4' flock .audit/mix.lock \
  python3 scripts/check-tests.py apps/gaoxy_http/test/gateway_generation_test.exs \
  apps/gaoxy_proxy/test/gateway_test.exs apps/gaoxy_server/test/route_config_test.exs \
  apps/gaoxy_server/test/route_resources_test.exs \
  apps/gaoxy_server/test/http3_generation_test.exs --seed 0 --max-cases 1
GAOXY_CONSUMER_DEPS="$PWD/deps" bash scripts/external-consumer.sh
bash scripts/http-consumer.sh
GAOXY_CONSUMER_DEPS="$PWD/deps" bash scripts/gateway-consumer.sh
GAOXY_CONSUMER_DEPS="$PWD/deps" \
  GAOXY_QUIC_PYTHON="$PWD/.audit/h2peer/bin/python" bash scripts/h3-gateway-consumer.sh
(cd examples/phoenix_native && PHOENIX_NATIVE_H3=1 PHOENIX_NATIVE_H2=1 \
  PHOENIX_NATIVE_RELOAD=1 MIX_ENV=dev mix compile --warnings-as-errors)
GAOXY_PHOENIX_EVIDENCE=.audit/unified-phoenix-final2 \
  .audit/unified-browser-venv/bin/python integration/phoenix_native/unified.py
mix format --check-formatted
MIX_ENV=prod mix compile --warnings-as-errors
MIX_ENV=prod mix release gaoxy --overwrite
python3 scripts/release-smoke.py
.audit/h2peer/bin/python scripts/gateway-release-smoke.py
.audit/h2peer/bin/python scripts/h3-release-smoke.py --evidence .audit/unified-release-h3
python3 scripts/test-stage-hex-packages.py
```

Raw local evidence is archived under [evidence/unified-gateway](evidence/unified-gateway/).
The original [source input manifest](evidence/unified-gateway/source-inputs.json) and
[package receipt](evidence/unified-gateway/package-receipt.json) preserve the reviewed
pre-compiler-correction source. The [final source manifest](evidence/unified-gateway/source-inputs-final.json)
fixes all 157 packaging inputs on `d206e55d`; the
[final package receipt](evidence/unified-gateway/package-receipt-final.json) records
five corrected-source archive hashes and all 122 runtime payload hashes.
[Committed-source exact log](evidence/unified-gateway/exact-committed.log.gz)
records 265 executions with zero failures/exclusions/skips on `d206e55d`. The earlier
[exact final log](evidence/unified-gateway/exact-final.log.gz),
[Phoenix report](evidence/unified-gateway/phoenix-final.json),
[core/HTTP review](evidence/unified-gateway/core-http-review.md) and
[Gateway review](evidence/unified-gateway/gateway-review.md), and
[release-preparation review](evidence/unified-gateway/release-preparation-review.md) retain executed
results and review boundaries. Raw logs use gzip without altering their content.

The final browser run required the existing NixOS GCC runtime library directory
in its process-local `LD_LIBRARY_PATH`; the earlier missing-libstdc++ import
failure remains archived. The successful run used pinned aioquic 1.2.0 and
reported eight PASS checks, source restoration and process exit 0. No host
configuration was changed.

The release workflow repeated external consumers, the exact ordinary gate, actual
unified Phoenix acceptance, strict builds, staging and package/release smokes on
the exact already-versioned source before irreversible publication. Configured
steps alone were not evidence; the actual completed hosted result is recorded below.

## Integration and merged-main verification

PR [#4](https://github.com/gsmlg-dev/gaoxy/pull/4) was merged normally at
`2539b3c400231c079eda7ad60f1c343101227eca`. Its head `2078ee8e` and actual
synthetic PR checkout have the same complete tree as the merge:
`74e3b6688f3e5648fdf23c87d96aa4d4f95f9c51`. Local and remote main were verified
at that merge. The [integration receipt](evidence/unified-gateway/integration.json)
and [PR CI receipt](evidence/unified-gateway/pr-ci-success.json) preserve these
identities. PR static `39624808606`, Unit `39624808585` and Foundation
`39624808820` completed successfully. Stale job-table metadata did not replace
the authoritative completed workflow results.

Merged-main static `39627274174` and Foundation `39627274265` PASS. Foundation
executed the exact 265-case gate with no failures/exclusions/skips and the
unified browser's eight checks, external consumers, portable releases and
ordinary platform gates. Its [summary](evidence/unified-gateway/main-foundation.summary.json)
and [raw log](evidence/unified-gateway/main-foundation.log.gz) preserve counts,
existing exclusions and unsupported IPv6-negative semantics separately.

Main Unit `39627273984` Linux PASS. macOS attempt 1 returned the expected H2
Continue timeout but failed the unchanged elapsed assertion at 104 ms < 100 ms;
one unchanged diagnostic retry failed the H1 delayed-gate elapsed assertion at
562 ms < 250 ms. Both file results are FAIL: 27/28 passed. The H1 native-result
and cleanup assertions after the elapsed assertion were not reached. The
[H2 diagnosis](evidence/unified-gateway/main-h2-deadline-diagnosis.md),
[H1 diagnosis](evidence/unified-gateway/main-h1-deadline-diagnosis.md) and
[environment comparison](evidence/unified-gateway/main-unit-environment.md)
identify unchanged production paths, fixture calls outside the request deadline,
and variable same-tree hosted execution. They do not establish the exact cause
of either elapsed breach. Original failures and metadata remain archived.

The next verification adds bounded caller scheduling and fixture-phase traces
to the three affected tests, without changing any assertion, threshold, case
count, product code or workflow setting. Off-scheduler intervals can include
legitimate blocking waits; they do not alone prove runnable starvation. Fresh
local verification using `ELIXIR_ERL_OPTIONS='+S 2:2'` executes 28 tests with zero
failures and three trace reports. The [independent instrumentation review](evidence/unified-gateway/deadline-instrumentation-review.md) is PASS. At that point the required hosted Unit gate was pending;
that local result did not relabel either previous failure or establish a repair.

The instrumented main run on `fd398884` preserved that distinction. Static
`39632125144` and Foundation `39632125090` PASS; Foundation again executed
265 cases with no failures/exclusions/skips and all eight unified browser checks.
Unit `39632124759` FAIL on macOS: 67 executed, 66 passed, one failed and 113
NOT RUN after the wrapper stopped. Ubuntu executed all 180 cases successfully.
The [Unit summary](evidence/unified-gateway/diagnostic-unit.summary.json) and
[raw macOS log](evidence/unified-gateway/diagnostic-unit-macos.log.gz) retain
the H2 Continue timeout result followed by the failed 105 ms < 100 ms assertion.
Its request spent 105.084 ms off-scheduler in `gen.do_call`; the trace did not
capture its timeout argument. A separate passing direct-H2 case spent 96.319 ms
waiting in `code_server.call`. Neither observation establishes the cause of the
failed Continue case or the earlier H1 failure.

[Runtime-source investigation](evidence/unified-gateway/diagnostic-h2-followup.md)
found identical finite `gen.do_call` timeout handling in OTP 28.5 and 29.0.2,
and no added grace in the relevant Elixir wrappers. The next controlled run
therefore adds actual call timeout/exception events and an independent timer
witness to the existing three caller traces. It keeps product code, workflow
settings, request deadlines, elapsed assertions and test counts unchanged.
The witness never queries or wakes the caller; its processing delay includes
timer delivery and collector scheduling, so it cannot alone identify OS or VM
root cause. Missing witnesses and dropped events are explicit.

The [matching-source local receipt](evidence/unified-gateway/deadline-witness-local.json)
records 28/0 with `+S 2:2`, three observed witnesses and no dropped events.
The [independent review](evidence/unified-gateway/deadline-witness-review.md) is
PASS. At instrumentation commit `0f8b7775`, enhanced hosted verification was
NOT RUN. Its subsequent completed Unit `39635685816` is PASS: all 180 cases
executed on each of Linux and macOS, including 28/0 in the affected file on each
platform. All six trace reports have observed witnesses and zero dropped events.
The [final Unit summary](evidence/unified-gateway/witness-unit.summary.json)
retains complete call/exception and timer observations. macOS H2 Continue passed
in 50.047 ms with an actual 30 ms call timeout and a witness processed 20 ms
late. The independent collector and caller were both delayed in this passing
attempt; this does not establish the earlier failures' causes or a product repair.
The direct-H2 case consumed its deadline during code loading before an H2 call
was emitted. All original elapsed assertions remain unchanged, and all earlier
failure evidence remains immutable.

Static `39635685732` and Foundation `39635685418` also completed successfully
on full release candidate `0f8b777590c16f3d3a2a334b5653a4c817f7b79a`.
Foundation executed the exact 265-case gate, eight unified browser checks,
external consumers and portable TCP/TLS/UDP release smokes on both platforms.
Existing portable loopback exclusions and unsupported IPv6-negative semantics
remain explicit in the [Foundation summary](evidence/unified-gateway/witness-foundation.summary.json).
The [release preflight](evidence/unified-gateway/release-preflight.json)
independently checked all three authoritative workflow results, exact remote
main and committed versions before dispatch. All 157 packaging inputs and five
staged archive hashes still match the final package qualification, as recorded
in the [publication-source identity check](evidence/unified-gateway/prepublication-identity.json).

## Publication

Coordinated release workflow
[`39638994661`](https://github.com/gsmlg-dev/gaoxy/actions/runs/39638994661)
completed successfully after all required main CI gates passed. The published
[`v0.8.0` tag and GitHub release](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.8.0)
identify exact source `0f8b777590c16f3d3a2a334b5653a4c817f7b79a`.
The [release summary](evidence/unified-gateway/release-run.summary.json) and
[raw log](evidence/unified-gateway/release-run.log.gz) retain the publication-source
265/0 gate, isolated consumers, eight unified browser checks, packaging regressions,
release smokes and actual upload/tag/release results.

Five public Hex distributions are version 0.8.0: `gaoxy_websock_adapter`,
`gaoxy`, `gaoxy_http`, `gaoxy_http3` and `gaoxy_proxy`. The
[independent public-artifact verification](evidence/unified-gateway/public-artifact-verification.json)
checks seven GitHub assets, six SHA256 entries, all five public Hex API versions
and checksums, byte equality between GitHub and Hex archives, exact staged file
sets and all 122 runtime payload files. The actual downloaded Linux x86_64
archive SHA256 is `ca030336e614dd510005efa6e00798c1cda091288c91f055ab0f0f2a064872ef`.
Public release-note guide links are pinned to the versioned documentation;
[page and raw-document checks](evidence/unified-gateway/public-guide-links-and-preservation.json)
all return HTTP 200 and match the tagged source.

The [downloaded-runtime receipt](evidence/unified-gateway/public-runtime.json)
is PASS: core TCP/TLS/UDP (3), Gateway exchanges (7) and H3 checks (3), with all
three commands exiting 0. [Application metadata](evidence/unified-gateway/public-runtime-versions.json)
confirms 0.8.0 for all five own applications. This executes the public archive,
independently of the local release build. NixOS qualification used both
process-local `LD_LIBRARY_PATH` and `NIX_LD_LIBRARY_PATH` from the receipt; no host
configuration changed. Vendored adapter provenance remains separate from its
coordinated public distribution version.

The [public Hex consumer receipt](evidence/unified-gateway/public-consumers.json)
is PASS: core 2/0, HTTP 5/0, Gateway 2/0 and H3 Gateway 2/0, totaling 11 executed
with no failures, exclusions or skips. All 16 isolated Mix commands exited 0.
These projects resolve exact public 0.8.0 packages, use separate dependency/build
directories and explicit WebSock overrides, and reject source fallback. All 13
consumed tar copies, covering the five distributions, match Hex API and GitHub
digests. Original test and H3 helper files remain unchanged. The
[raw harness receipt](evidence/unified-gateway/public-consumers.raw.json) retains
fixture preparation source `14c5fd91` and its original preparation note; the
publication receipt separately identifies executed package source `0f8b7775`
and links the raw receipt by SHA256. [Project sources and locks](evidence/unified-gateway/public-consumer-projects.tar.gz)
exclude dependency/build/cache outputs and preserve the actual isolated inputs.

Public verification commands are preserved with their logs and receipts:

```sh
GAOXY_EXPECTED_RELEASE_SHA=0f8b777590c16f3d3a2a334b5653a4c817f7b79a \
  GODEBUG=http2client=0 python3 .audit/verify-unified-public.py
# With the process-local library paths recorded in public-runtime.json:
python3 .audit/unified-public-runtime.py
python3 .audit/unified-public-consumers-validate.py run \
  --publication-signal 'https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.8.0 source 0f8b777590c16f3d3a2a334b5653a4c817f7b79a; workflow 39638994661 SUCCESS'
```

Verifier sources are archived as `public-*-verifier.py.gz` beside the receipts.
They originally execute from the repository's `.audit/` directory; consumer
preparation uses the unchanged integration tests and accepted dependency cohort.
Later documentation/evidence commits do not change the published source or
package inputs. The [independent closeout review](evidence/unified-gateway/closeout-review.md)
is PASS with no remaining actionable findings, including publication identity,
consumer provenance, actual runtime checks, checklist completion and preserved
historical failures. Deployment remains NOT RUN and outside authorization.

## Preserved failures and limits

The first expanded exact gate failed six unchanged WorkerAccounting tests:
adding `Exchange.discovery` changed its complete ETF constructor. Adding the
missing nil field to the numeric constructor corrected the model; all seven
independent accounting cases then passed. No assertion or reservation constant
was weakened. The second attempt exposed a Phoenix test using the adapter's
new logical owner PID as a core instance. The test now resolves the core through
the public ListenerSet inspection API and preserves all seven real-peer cases.
Its teardown also exposed ignored host shutdown in ListenerSet.Owner; the final
repair and its direct lifecycle regression are recorded separately.

Hosted Elixir 1.20 strict compilation exposed two unreachable outer `with ... else`
clauses in `Gateway.do_reload_routes/4`. The two-line correction removes only those
clauses; the inner missing-set branch and public invalid-options guard remain.
[Independent review](evidence/unified-gateway/elixir120-review.md) is PASS. Fresh
local Gateway/lifecycle verification is 20/0, the complete committed-source gate
is 265/0, and formatting/strict production compilation exit 0. The original
[hosted compiler failure](evidence/unified-gateway/hosted-elixir120-initial-failure.log.gz)
is retained; a local 1.18 result is not a claim of hosted 1.20 success.

Existing failures reproduced on untouched baseline remain separate:

- `standalone_upstream_runtime_test.exs`: 9 tests, 5 failures for existing managed
  h2c/http2 fixed/group 502/503 responses. This work does not establish those
  upstream paths as newly qualified.
- `http_contract_test.exs`: 15 tests, 1 failure at the existing 40 ms chunk
  metadata receive timeout.
- The previously recorded H1 upload/body-copy admission failure with a 4096-byte
  service budget remains in [mixed H2c acceptance](mixed-h2c.md).

No specialist exceptional/disconnect/pressure/soak campaign was run or revived.
Historical failures retain their actual status. `http_fetch#97` stays outside
acceptance. H3 unsupported address/TLS features and local-host cleanup limits
remain explicit. Port-zero TCP/UDP allocation is independent; no listener or
certificate hot reload, cross-set transaction, durable control plane, complete
root/VM recovery, public management endpoint or automatic certificate issuance
is added. Cached Alt-Svc can outlive later loss of readiness. Production
deployment/data/certificates, Vault changes and the disabled release-artifact
E2E workflow remain outside this work.
