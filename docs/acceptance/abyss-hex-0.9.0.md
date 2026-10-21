# Abyss Hex migration and Gaoxy 0.5.5 acceptance

Date: 2026-10-21 (Asia/Shanghai). Development is directly on `main`, as requested.
Base: `fbb2b2b60f7ff44ba459d164e52e82dc82ddb973` (Gaoxy 0.5.4).
This record distinguishes local verification from hosted CI and publication.

## Upstream prerequisite and selected dependency

**PASS:** coordinated Abyss release **0.9.0**, tag `0.9.0`, source commit
`f336d939ff8a23b38c66072f1d1ba5873b5ef43b`, published GitHub Release
<https://github.com/gsmlg-dev/abyss/releases/tag/0.9.0>.
Both real Hex downloads returned HTTP 200. Their SHA-256 values match Hex API
and the release record; all packaged regular files match that commit's Git tree
(core 47/47, raw 11/11). See [upstream receipt](evidence/abyss-hex-0.9.0/upstream-release.json).
The `releases/latest` endpoint still returned 0.8.1 during inspection; selection
used the release list, exact tag endpoint and both actual package publications.

| Package | SHA-256 of downloaded public archive |
|---|---|
| abyss 0.9.0 | `d13364b95d070abce970c5e7633e49648f9fc9157a7ca5f4d88464454b6d7a48` |
| abyss_raw 0.9.0 | `6fea2ac8089c09a0ab58fbc96031b29badd83d50486c9ee3b29eb15a2a567c9d` |

Gaoxy previously selected Git Abyss
`9b710e6480900e16e304f40e63623aff8c922e19` (self-declared 0.7.0 with bundled
DHCP Rust NIF). It now selects Hex **`abyss == 0.9.0`**. `abyss_raw` is not
added to any service dependency. No adapter or runtime implementation changed.

## Dependency and package boundary

**PASS:** normal `mix deps.unlock abyss`, `mix deps.get`, graph inspection and
`mix deps.unlock --unused` resolved all three tracked locks. In root and optional
QUIC locks only Abyss changes and unused Rustler/Jason disappear. In the Phoenix
lock only Abyss changes and Rustler disappears; its directly required Jason stays.
Every other pre-existing entry remains byte-identical, including Hell and each
HTTP/TLS/QUIC package. Optional QUIC retains 0.21.4; the root cohort retains 0.21.10.

Fresh dependencies were fetched under `.audit/abyss-hex-0.9.0/`; separate build
roots were used for the test, production, network and consumer executions.
`mix deps.tree` and a scan of all **22** root locked dependencies found neither
Rustler nor `abyss_raw`, Rust/Cargo sources/builds, NIF loaders, or packaged native
sources/libraries. Installed Abyss files match the downloaded core archive
**47/47**. See [dependency receipt](evidence/abyss-hex-0.9.0/dependency-boundary.json).
The former Abyss-owned DHCP native build is gone from this active graph.
Core retains `Abyss.DhcpSocket.Native` as an Elixir compatibility facade for the
optional raw package; it contains no NIF loader or native implementation and
returns a missing-optional-dependency error when the raw implementation is absent.
Erlang/OTP's ERTS, `crypto` NIF/OpenSSL and platform runtime libraries remain
native dependencies owned by OTP; this does not claim a native-free application.
Python/aioquic and cryptography are independent verification tools.

Staging no longer translates the old Abyss Git pin to Hex 0.7.0. Unsupported
Git/path inputs still fail before staging output. The old pin regression was
observed red (1 test, 1 failure, exit 1) and green (1 test, 0 failures, exit 0).
Nine packaging regressions pass, including real archive metadata and payload
inspection. Five actual 0.5.5 packages were built; core metadata requires
`abyss`, repository `hexpm`, requirement `== 0.9.0`, nonoptional. No package
declares `abyss_raw` or Rustler. Final workflow artifacts are verified separately
after publication; these local tarballs are preparation evidence.

## Executed local gates

Environment: Linux x86_64, Elixir 1.18.5, OTP 28.5.0.5 / ERTS 16.4.0.5;
OpenSSL 3, pinned h2 4.3.0 and aioquic 1.2.0 peers. Root and optional-QUIC
checks use `ELIXIR_ERL_OPTIONS='+S 4:4'`; Phoenix and network receipts record
`+S 2:2`. Repair wrappers select `MIX_ENV=test`.
Logs and command receipts are under `.audit/abyss-hex-0.9.0/`.

| Command / scope | Result |
|---|---|
| `mix deps.get --check-locked`; fresh `mix compile --warnings-as-errors` | PASS, exit 0, dev and prod |
| `mix format --check-formatted` | PASS, exit 0 |
| `python3 scripts/test-check-tests.py` | PASS, 8 tests, exit 0 |
| `python3 scripts/test-check-repairs.py` | PASS, 6 tests, exit 0 |
| `python3 scripts/test-release-smoke.py` | PASS, 5 tests, exit 0 |
| `python3 scripts/test-stage-hex-packages.py` | PASS, 9 tests, exit 0 |
| `python3 scripts/check-repairs.py all` | PASS, 160 executed, 0 failures/excluded/skipped, exit 0 |
| `scripts/check-tests.py` on config, datagram dispatcher/egress, backend telemetry, lifecycle ownership, QUIC context, certificates and TLS test files | PASS, 19 tests, 0 failures, exit 0 |
| `scripts/check-tests.py apps/gaoxy/test/runtime_test.exs:157`, `:178`, `:264` | PASS, 1 selected case each; 21 unrelated cases excluded across 3 invocations; exit 0 each |
| `bash scripts/external-consumer.sh` with fresh external deps/build | PASS, 1 real TCP/UDP test, forbidden dependencies include `abyss_raw` and Rustler, exit 0 |
| `integration/quic_consumer`: normal resolution, strict compile, `scripts/check-tests.py` | PASS, 4 tests with independent validating peer, exit 0 |
| `examples/phoenix_native`, `PHOENIX_NATIVE_H3=1`: normal resolution, strict compile, focused `mix test` | PASS, 5 tests, exit 0 |
| `integration/network/fixture.py --allow-privileged`, inet IPv4 / IPv6, socket IPv4 / IPv6 | PASS, 13 / 21 / 13 / 20 gates, exit 0 each |
| `integration/network/release_gate.py --allow-privileged` | PASS, 11 gates, five transports, two independent peers, exit 0 |
| `integration/network/example_gate.py --allow-privileged` | PASS, 11 gates, five transports, two independent peers, exit 0 |
| `MIX_ENV=prod mix release gaoxy` | PASS, exit 0, fresh production build |
| `scripts/release-smoke.py` | PASS, TCP/TLS/UDP startup/traffic, SIGTERM drain, endpoint reuse, exit 0 |
| `scripts/gateway-release-smoke.py --release <fresh launcher>` | PASS, 2 native H1/H2 exchanges and shutdown/rebind, exit 0 |
| `scripts/h3-release-smoke.py --release <fresh launcher> --evidence <directory>` | PASS, 3 native H3/fixed-H3-origin checks and finite shutdown, exit 0 |

Network fixtures run unchanged from a temporary copy of current source (not a
worktree), with fresh Hex dependencies and a dedicated build. The IPv6 socket
scoped-send capability retains its existing explicit **UNSUPPORTED** negative
gate; passing that assertion does not claim support. The core smoke uses an
unchanged script copy linked to the fresh production release because its default
launcher path is fixed. No production service is involved.

The first parallel core/H3 smoke attempts **FAILED** during startup because the
smokes share the default distributed Erlang node name. Those logs and exits 1
remain preserved in `logs/release-{core,h3}-smoke.log`. Sequential retries with
unchanged assertions **PASS**; their logs use the `-serial` suffix. This was a
local verification orchestration conflict, not an integration repair.

## Review, hosted gates and publication

Independent specification and code review **PASS**, with no blocking findings.
The review inspected five real tarballs (123 source payloads) and 420 recorded
source hashes. Its minor environment-description correction is applied above.
Fresh post-review packaging (9 tests) and focused core contracts (19 tests)
**PASS**. All 64 recorded raw log hashes and 12 recorded build inputs were
rechecked against the committed evidence and current source.

Migration commit `a6234ef03f5bf2879e7f7cf47879f44ceeb93045` is pushed to
`origin/main`; remote identity was verified before publication. Hosted gates on
that exact source are recorded in
[the hosted receipt](evidence/abyss-hex-0.9.0/hosted-gates.json):

| Required workflow | Result |
|---|---|
| [Static checks and build 39536906214](https://github.com/gsmlg-dev/gaoxy/actions/runs/39536906214) | PASS, Linux and macOS, attempt 1 |
| [Foundation integration tests 39536906372](https://github.com/gsmlg-dev/gaoxy/actions/runs/39536906372) | PASS, all five jobs, attempt 1; native HTTP job executes all 160 repair cases |
| [Unit tests 39536906298](https://github.com/gsmlg-dev/gaoxy/actions/runs/39536906298) | Linux PASS; initial macOS FAIL; sole unchanged-source macOS rerun PASS, 141 required cases, no failures/exclusions/skips |

The initial macOS failure remains **FAIL**: `plug_body_test.exs` lines 298 and
321 returned the expected timeout but measured 320 ms against limits of 100 ms
and 250 ms. That file executed 28 cases, passing 26; the wrapper stopped before
the remaining files. Independent inspection found 14 relevant source, test,
wrapper and workflow files byte-identical to baseline `fbb2b2b6`; neither measured
path calls Abyss. Baseline hosted unit run `39478699571` passed both platforms.
The sole diagnostic rerun preserved the source, assertions and declared matrix
configuration and passed all 141 required unit cases. This establishes an
intermittent result, without proving a pre-existing failure or a host-timing
cause. Original failure logs and both attempts are retained; no HTTP code,
deadline or test limit was changed. Publication waited for the required rerun
to complete successfully.

**PASS:** publication used the existing
[release workflow 39539245005](https://github.com/gsmlg-dev/gaoxy/actions/runs/39539245005),
dispatched with `version=0.5.5`, `git_ref=main` and the exact migration SHA.
It executed all 160 repair cases with no failures, exclusions or skips, built
the production release and passed core, H1/H2 gateway and H3 release smokes.
See [workflow receipt](evidence/abyss-hex-0.9.0/release-workflow.json).

**PUBLISHED:** [Gaoxy v0.5.5](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.5.5),
2026-10-21 11:36:10 Asia/Shanghai. The tag points to the migration commit.
Hex `gaoxy_websock_adapter`, `gaoxy`, `gaoxy_http`, `gaoxy_http3` and
`gaoxy_proxy` are all published as **0.5.5**, together with the Linux x86_64
standalone application and `SHA256SUMS`.

**PASS:** public artifact verification downloaded all five real Hex archives,
their API metadata and all GitHub Release assets. The six payloads match
`SHA256SUMS`; each Hex archive matches its API checksum and GitHub asset bytes.
All **128** package payload files match the exact source after regenerating
staged manifests with the committed script; 347 controlled input files were
compared to Git objects. Published core metadata requires exactly
`abyss == 0.9.0`, repository `hexpm`, nonoptional. No published package declares
`abyss_raw` or Rustler. See [publication receipt](evidence/abyss-hex-0.9.0/publication.json).

The standalone archive has 1,447 entries, Abyss 0.9.0 and all five own apps at
0.5.5, with no raw/Rustler or DHCP native implementation payload. Its SHA-256 is
`9dce083627711c8b03d4d1ef04b79a9a33948018bf689ea0459506c7ec56d18b`.
Its four `.so` files belong to OTP: ASN.1's `asn1rt_nif.so`, and crypto's
`crypto.so`, `crypto_callback.so`, `otp_test_engine.so`. ERTS and platform native
runtime dependencies also remain. Standalone provenance is tied to the
successful workflow's exact source and source/build/publication steps; the
downloaded binary was inspected, not reproduced byte for byte or executed
locally. Runtime smokes ran against the workflow's built release before upload.

**PASS:** a fresh public consumer with only `{:gaoxy, "== 0.5.5"}` started
without dependencies, build output or a lockfile. Normal `mix deps.get`,
`mix compile --warnings-as-errors`, `mix test`, `mix deps.tree` and actual graph
inspection all exit 0. Its **1 test, 0 failures** executes real TCP and empty UDP
round trips and listener shutdown. All 11 resolved dependencies use `Hex.SCM`;
actual Gaoxy/Abyss/Hell versions are 0.5.5/0.9.0/0.1.2. The 16 forbidden raw,
Rustler and optional HTTP/QUIC/server apps are neither resolved, installed nor
running. No Git/path override was used. Commands, environment, graph, source and
log hashes are in [the consumer receipt](evidence/abyss-hex-0.9.0/public-consumer.json).

Independent closeout review **PASS**: public core archive metadata/checksum,
remote tag, successful exact-source release workflow and native/provenance
statements were independently checked. No publication blocker remains. This
evidence-only closeout follows the release commit without changing its payload.

Deferred specialist abnormal/pressure/load slices, disabled release-artifact E2E,
deployment, production data/certificates, public management and Vault changes
remain outside this task. Existing historical evidence and unrelated user files
are preserved.
