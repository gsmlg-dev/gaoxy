# Unified listeners and embedded Gateway acceptance

Date: 2026-10-21, Asia/Shanghai. Specification: Agent Note
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

Status: ordinary implementation and verification PASS. Independent source
and release documentation reviews PASS. Publication
and deployment remain separately recorded below.

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
| Push and hosted CI | PR [#4](https://github.com/gsmlg-dev/gaoxy/pull/4) open; initial Linux jobs PASS, initial macOS compiler jobs FAIL; corrected-source hosted verification pending |
| Coordinated publication | NOT RUN |
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

The release workflow repeats external consumers, the exact ordinary gate, actual
unified Phoenix acceptance, strict builds, staging and package/release smokes on
the exact already-versioned source before irreversible publication. Configured
workflow steps are not an executed hosted result.

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
