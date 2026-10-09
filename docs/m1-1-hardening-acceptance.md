# M1.1 hardening acceptance

Date: 2026-10-09 (Asia/Shanghai). Scope is F1–F5 in the supplied
`gaoxy-m1.1-fix-prompt.md`; M2 and new transport/protocol features are excluded.
The historical M1 snapshot is not reused as passing evidence for these changes.

## Source and environment

Initial checkout: `main`, `adafa668937ed9a919cc82fcae14ae50863b5ac6`.
Only `gaoxy-m1.1-fix-prompt.md` was untracked initially; it is preserved and is not
part of the candidate commit. No reset or dependency-source modifications occurred.
Implementation commit: `5a77e0629a94e271ae74d28dcc2de9452d54e571`.
Final executable/test candidate: `8ae2b6db0a025461ef660148ef96de9a9ce280c3`, on
`codex/m1-1-hardening` in `.trees/m1-1-hardening-ci`;
[draft PR #1](https://github.com/gsmlg-opt/gaoxy/pull/1). Follow-up commits repair
test synchronization, the independent TLS peer and release-smoke harness, and add
deterministic harness regressions to canonical CI. Production libraries,
isolated-network scripts, consumer manifests and lockfiles are identical to the
implementation commit. The original
`main` HEAD remains unchanged and retains all implementation edits.

Local runs used the original checkout **plus the implementation diff**, not
unchanged baseline source. The [source manifest](acceptance/evidence/m1-1/candidate-source.json)
records individual SHA-256 values and ties these bytes to the committed candidate.
The final local full-suite/formatter run checked hashes before and after execution.
Hosted PR jobs check out synthetic merge
`b78d656b6f2e6ade05025a33ddff5fd76b522f1e`, with parents the baseline and candidate;
its full tree `fb516ff26d9fef8eefab30e76a1ae6b6ad5dd5ce` equals the candidate tree.
Any later acceptance-document/evidence commit leaves those executable inputs
unchanged; it does not create a new untested lifecycle implementation.

Local host: NixOS Linux x86_64, kernel 6.18.33; Elixir 1.18.5, OTP 28.5.0.5,
ERTS 16.4.0.5. Core/network/release runs set `ELIXIR_ERL_OPTIONS='+S 2:2'`.
The final local optional QUIC run used the host's default schedulers
(`max_cases: 96` in its log); hosted QUIC jobs use `+S 2:2`.
OpenSSL executable `/run/current-system/sw/bin/openssl`, version 3.6.3.
Independent ordinary peer: CPython 3.13.15/OpenSSL 3.6.3.
Abyss 0.7.0 is locked to `9b710e6480900e16e304f40e63623aff8c922e19`;
Thousand Island 1.5.0 to `6146e1bfdd1a85c5c16c3c92ad98ff5f11066820`;
Telemetry 1.4.2. Lockfiles and installed dependency sources remain unchanged.
UDP `inet` and `socket` backends run separately. Runtime-matrix CI uses Ubuntu
24.04.5 x86_64 with Elixir 1.18.5/OTP 28.5.0.7 (ERTS 16.4.0.6), and macOS
15.7.9 x86_64 with Elixir 1.20.1/OTP 29.0.2 (ERTS 17.0.2).
Hosted ordinary peers use CPython 3.14.8 on Linux and 3.14.7 on macOS;
their linked SSL version is not separately logged. Certificate generators log
`/usr/bin/openssl` on Linux and
`/usr/local/opt/openssl@3/bin/openssl` on macOS, versions 3.0.13 and 3.6.3
respectively. The optional local peer is CPython 3.12.13/OpenSSL 3.5.7,
aioquic 1.2.0, cryptography 50.0.2 and pylsqpack 0.3.24; the optional consumer pins
`elixir_quic` and `ex_ssl` 0.17.0.

## Revalidation and implementation

| Finding | Baseline classification and cause | Implemented behavior and regression evidence |
|---|---|---|
| F1 | **REPRODUCED**: actual parent Supervisor shutdown killed admitted TCP/UDP work before emitting a drain transition. Service termination stopped the gate first. | Instance dispatches concurrent service barriers and retains callback loops/I/O under one absolute deadline. TCP, verified TLS and UDP parent tests cover both completion and forced closure; UDP proves the original response source port and later exclusive bind reuse. Two stalled services have exactly equal deadlines and both closed gates before cleanup. Standalone SIGTERM test holds admitted TCP/TLS clients until their responses finish. |
| F2 | **REPRODUCED**: killing the public registration owner allowed real TCP/UDP exchanges while lookup remained missing. Registry startup also leaked an ArgumentError instead of the documented error. | Monitored lifecycle/telemetry owners; one bounded reconciliation timer; both bindings restored under the same generation, or confirmed fail-closed closure. Tests cover partition/whole Registry replacement, abrupt root death, sustained outage, paused/draining services, startup, two instances with identical IDs, telemetry attribution, partial registration, stale timers and replacement. Registry-backed instance names themselves fail closed on owner loss. |
| F3 | **REPRODUCED**: killed drain helper returned `:ok`; deadline code sent kills without confirmation; instance stop discarded removal errors. | Confirm resources and service/instance exit; helper errors/exceptions/normal exit without completion trigger emergency cleanup and structured errors. Caller deadlines return uncertainty, failures aggregate, caller death does not abandon cleanup, duplicate operations are bounded, stale messages cannot affect a replacement. Regressions retain real socket/lease cleanup assertions. |
| F4 | **REPRODUCED**: removing a required TCP backend child made suspend fail after the gate had closed, leaving advertised `:ready`. | Explicit pausing/resuming transitions; commit only after backend and gate success. Backend error/exit/timeout leaves fail-closed state; uncertain gate coordination forces cleanup. Repeated calls, backend failures, gate failures after backend success and late resume during drain are covered. |
| F5a | **REPRODUCED** locally and in baseline static run `37759455187`: Elixir 1.18.5 formatter rejected guarded layout in service/config; compilation was **skipped**, not failed. | Canonical formatter 1.18.5 in an independent job; older/newer runtime compile/test matrices retained. Formatting, strict local compilation and idempotence checked. Test-count harness now rejects all-excluded/all-skipped runs in both ExUnit formats. |
| F5b | Baseline macOS failure **REPRODUCED from logs**, underlying issuer-error cause **NOT REPRODUCED / NEEDS EVIDENCE** locally: run `37759455253`, job `113252030848` failed two fixture verifications before any TLS listener started. Tool/config/certificate artifacts were absent; consumer/release steps were skipped. | Concrete portability defects reproduced and fixed: ignored OPENSSL_BIN, dependence on machine profiles, hidden generation diagnostics. Validated OpenSSL 3 executable, explicit CA/leaf extensions/SAN/EKU/SKI/AKI, isolated serial/signing files, restrictive permissions and strict chain/purpose/DNS/IP checks. Wrong-CA and wrong-hostname negatives plus real verified TLS remain. Linux OpenSSL and LibreSSL both passed the original issuer check, so tool replacement alone is not claimed as the causal diagnosis. Full candidate macOS execution is required. |

Implementation paths and regression files:

| Finding | Main changed paths |
|---|---|
| F1 | [Instance](../apps/gaoxy/lib/gaoxy/instance.ex), [Service](../apps/gaoxy/lib/gaoxy/service.ex), [Lifecycle](../apps/gaoxy/lib/gaoxy/lifecycle.ex), [parent-shutdown tests](../apps/gaoxy/test/shutdown_hardening_test.exs), [standalone smoke](../scripts/release-smoke.py) |
| F2 | [RegistryPolicy](../apps/gaoxy/lib/gaoxy/registry_policy.ex), [Telemetry](../apps/gaoxy/lib/gaoxy/telemetry.ex), Instance/Service integration, [Registry tests](../apps/gaoxy/test/registry_failure_test.exs) |
| F3 | [Public API](../apps/gaoxy/lib/gaoxy.ex), Instance/Service/Lifecycle, [Admission](../apps/gaoxy/lib/gaoxy/admission.ex), [fault tests](../apps/gaoxy/test/lifecycle_fault_test.exs), [ownership tests](../apps/gaoxy/test/lifecycle_ownership_test.exs) |
| F4 | Service coordinated controls, [fault tests](../apps/gaoxy/test/lifecycle_fault_test.exs), [real pause/drain acceptance](../apps/gaoxy/test/lifecycle_acceptance_test.exs) |
| F5 | [Fixture generator](../scripts/generate-fixtures.sh), [static CI](../.github/workflows/ci.yml), [portable CI](../.github/workflows/portable.yml), [fixture tests](../apps/gaoxy/test/certificate_fixture_test.exs), [TLS peer](../integration/tls_peer.py), [test counter](../scripts/test-check-tests.py), [QUIC fixture regression](../integration/quic_consumer/test/quic_test.exs) |

## Contracts and compatibility

[ADR 004](adr/004-lifecycle.md) is authoritative for operation errors, resource
ownership and outer budgets. `:ok` requires confirmation within the total caller
budget; a small timeout can now return
`{:error, {:deadline_exceeded, :cleanup_pending}}` where the old implementation
returned premature success. Existing forced-drain tests now expect that truthful
result and still verify worker death, endpoint closure, lease release and stale
message isolation. Telemetry distinguishes completed, forced, cleanup failure
and unconfirmed termination. The outer instance child spec is the maximum initial
service drain timeout plus 2,000 ms headroom; later service addition cannot enlarge
that installed budget. `:kill`, VM termination and shorter external supervisor
budgets do not carry a cooperative-drain promise.

Registry reconciliation has a 1,000 ms absolute window and one retry per 25 ms.
Public management reports `:registry_unavailable` during missing/partial bindings.
A Registry-named instance drains and stops normally on loss of its own name;
atom-named/PID instances recover their service bindings independently. No recovery
message starts a backend or changes admission. QUIC still offers only local host
cleanup; pause, application/protocol graceful drain, IPv6/wildcard QUIC binds,
DATAGRAM, mTLS, migration and 0-RTT remain unsupported. HTTP, WebSocket,
Plug/Phoenix and proxy features remain M2+ and are not implemented here.

## Final-candidate gate ledger

Commands below use `ELIXIR_ERL_OPTIONS='+S 2:2'` except the final local optional
QUIC run noted above; working directory is the repository root unless explicitly
given. PASS means an actual successful execution,
not a workflow definition, historical result or excluded test. Focused cases are
included in the full-suite counts and are not added again as independent tests.

| Gate | Status | Exact command / execution evidence |
|---|---|---|
| Full local core/server suite, including F1–F4 and verified TLS/fixture tests | PASS | `python3 scripts/check-tests.py --seed 0`: exit **0**, **63 core + 1 server = 64 executed/passed**, 0 failures/skips/exclusions; [log](acceptance/evidence/m1-1/local-full-suite.log) |
| Canonical formatting and idempotence | PASS | Elixir 1.18.5: `mix format` twice, then `mix format --check-formatted`, `git diff --check`: each exit **0**, identical before/after source hashes; [log](acceptance/evidence/m1-1/local-formatter-idempotence.log) |
| Nonempty acceptance wrapper | PASS | `python3 scripts/test-check-tests.py`: exit **0**, **8 tests**, 0 failures; process-level old/new ExUnit formats, exclusions, skips and failure-status preservation; [log](acceptance/evidence/m1-1/local-harness-regressions.log) |
| Release harness synchronization | PASS | `python3 scripts/test-release-smoke.py`: exit **0**, **5 tests**, 0 failures; partial readiness writes, child exit diagnostics, connection reset before refusal, and unchanged absolute deadlines; [log](acceptance/evidence/m1-1/local-harness-regressions.log) |
| Workflow syntax | PASS | `actionlint -shellcheck='' .github/workflows/ci.yml .github/workflows/portable.yml`, actionlint 1.7.12: exit **0**; [log](acceptance/evidence/m1-1/local-actionlint.log) |
| Independent ordinary core consumer | PASS | `bash scripts/external-consumer.sh`: fresh external project, strict compile and **1 test passed**, exit **0**; [log](acceptance/evidence/m1-1/local-external-consumer.log). Git object cache reused after transport-fetch failure, not a claim of uncached fetching. Hosted consumers also run without this local override. |
| Local strict production compile and release | PASS | `MIX_ENV=prod mix compile --warnings-as-errors`, `MIX_ENV=prod mix release --overwrite`: both exit **0**; [compile](acceptance/evidence/m1-1/local-release-compile.log), [build](acceptance/evidence/m1-1/local-release-build.log) |
| Standalone stop/SIGTERM | PASS | `python3 scripts/release-smoke.py`: exit **0**, **3 transports**; admitted TCP/verified-TLS responses after both listener-refusal barriers, live VM until clients close, VM exit 0, exclusive UDP endpoint reuse; [log](acceptance/evidence/m1-1/local-release-smoke.log) |
| Isolated Linux inet IPv4 | PASS | `python3 integration/network/fixture.py --allow-privileged`: exit **0**, **13 gates**; [log](acceptance/evidence/m1-1/local-network-inet-ipv4.log) |
| Isolated Linux inet IPv4/IPv6 | PASS | Same with `--ipv6`: exit **0**, **21 gates**; [log](acceptance/evidence/m1-1/local-network-inet-ipv6.log) |
| Isolated Linux socket IPv4 | PASS | `GAOXY_UDP_BACKEND=socket python3 integration/network/fixture.py --allow-privileged`: exit **0**, **13 gates**; [log](acceptance/evidence/m1-1/local-network-socket-ipv4.log) |
| Isolated Linux socket IPv4/IPv6 | PASS | Same with `--ipv6`: exit **0**, **20 gates** (19 positive and the explicit unsupported scoped-send negative); [log](acceptance/evidence/m1-1/local-network-socket-ipv6.log) |
| Five-transport production release | PASS | `python3 integration/network/release_gate.py --allow-privileged`: exit **0**, **11 checks**, **5 transports**, **2 independent peers**, all five binds reusable; [log](acceptance/evidence/m1-1/local-five-transport-release.log) |
| Shipped custom-handler example | PASS | `python3 integration/network/example_gate.py --allow-privileged`: exit **0**, **11 checks**, **5 transports**, **2 independent peers**, all five binds reusable; [log](acceptance/evidence/m1-1/local-mixed-example.log) |
| Optional independent QUIC | PASS locally and in both hosted jobs | In `integration/quic_consumer`: `mix compile --warnings-as-errors`, then `python3 ../../scripts/check-tests.py`: exit **0**, **2 tests**, 0 failures/skips/exclusions, **5 independent-peer gates** plus facade/lifecycle assertions; [local log](acceptance/evidence/m1-1/local-quic-tests.log); final hosted Foundation runs below |
| Hosted canonical formatting and strict runtime compilation | PASS | Candidate `8ae2b6d`, PR static run [37824956485](https://github.com/gsmlg-opt/gaoxy/actions/runs/37824956485) and push static run [37824949930](https://github.com/gsmlg-opt/gaoxy/actions/runs/37824949930): canonical formatting plus **8 counter + 5 smoke regressions** pass in each; `mix compile --warnings-as-errors` exits **0** on both retained runtimes in both runs |
| Hosted Linux/macOS non-loopback tests | PASS | PR unit run [37824956454](https://github.com/gsmlg-opt/gaoxy/actions/runs/37824956454): `python3 scripts/check-tests.py --exclude loopback`, exit **0**, **7 core + 1 server = 8 executed/passed per platform**, 56 core loopback tests excluded; 0 failures/skips |
| Hosted Linux portable integration | PASS | PR job **113475295466**, push job **113475457063**: each executes **56 loopback tests**, **1 external-consumer test**, and full **3-transport release smoke**; each command exits **0**. Loopback selection excludes 7 core and 1 server test, and has 0 failures/skips |
| Hosted macOS portable integration | PASS | PR job **113475295615**, push job **113475457506**: same **56 + 1 + 3-transports** results, including certificate generation, verified TLS negatives, admitted post-SIGTERM responses, VM exit and UDP reuse. Both previously skipped downstream consumer/release steps actually execute |
| Hosted isolated Linux networking | PASS | PR job **113475295585**, push job **113475457543**: each executes inet IPv4 **13**, inet IPv4/IPv6 **21**, socket IPv4 **13**, socket IPv4/IPv6 **20**, then five-transport release **11** and mixed example **11** checks; every command exits **0** |

Final hosted Foundation runs: [PR 37824956605](https://github.com/gsmlg-opt/gaoxy/actions/runs/37824956605)
and [push 37824949968](https://github.com/gsmlg-opt/gaoxy/actions/runs/37824949968).
Across these and the static/unit runs above, **all five workflows and all 16 jobs
completed successfully**, with no failed, skipped or cancelled acceptance steps.
[Final CI metadata](acceptance/evidence/m1-1/ci-final-evidence.json) records every
job/step conclusion, exact numbered log excerpts and raw-log hashes. Excluded
test selections remain explicit; the split unit/loopback jobs cover all 64 tests.

Local network, five-transport release/example and consumer logs predate the
acceptance-test follow-ups. Their production/script/config/lock inputs are
byte-identical to the final candidate. The standalone smoke was rerun after its
harness repair. Final hosted jobs run the complete final tree, including the
corrected tests. Namespace tests used prepared, passwordless-sudo Linux runners
and fixture-owned namespaces; no host LAN routes/interfaces were changed. Owned
namespaces/processes were cleaned up.

The consumer cache override was exactly:

```sh
GIT_ALTERNATE_OBJECT_DIRECTORIES="$PWD/deps/thousand_island/.git/objects:$PWD/deps/abyss/.git/objects" \
ELIXIR_ERL_OPTIONS='+S 2:2' bash scripts/external-consumer.sh
```

Only verified exact-lock Git objects were reused; the external project and build
were fresh. Optional consumer provisioning similarly reused those clean Git
objects after two ordinary GitHub fetches failed with curl 56/early EOF; the
canonical remotes, manifests and locks were retained.

## Regression coverage and observed repairs

- `shutdown_hardening_test.exs`: **8 tests**. Real parent-supervisor TCP/TLS/UDP
  completion and force paths, retained original UDP socket/source port, helper
  death and real backend pause failure. Graceful TLS is final green execution;
  an early red TLS setup had an ALPN error and is not counted as a shutdown
  reproduction.
- `lifecycle_fault_test.exs`: **14 tests**. Two-service shared deadline and early
  barriers; helper errors/exceptions/block/normal exit without completion;
  false-success helper; zero/small budgets; caller death; repeated stop/remove;
  aggregate failures; backend/gate transition errors, timeout and late resume.
  The forced parent path confirms the original UDP sockets and every captured
  owned descendant are closed before immediate exclusive endpoint reuse.
- `registry_failure_test.exs`: **12 tests**. Partition/whole-Registry failure,
  real traffic, bounded outage/startup/partial-registration errors, paused and
  draining recovery, telemetry identity, identical IDs in separate instances,
  conflicts, fresh generations, and both Registry via-name forms.
- `lifecycle_ownership_test.exs`: **3 tests**. Registered-name OTP ancestry,
  unrelated raw handler links excluded, direct QUIC host reader included.
- `certificate_fixture_test.exs`: **3 tests**, plus the real `tls_test.exs` peer.
  Executable-path validation, hostile machine config/stale serial isolation,
  mode 0600 and signing-key cleanup, strict purpose/DNS/IP chain checks, wrong-CA
  and wrong-hostname rejection. See [certificate diagnostics](acceptance/evidence/m1-1/certificate-diagnostic.log)
  for issuer/subject, CA/leaf extensions, SKI/AKI, SAN/EKU and matching public keys.
- The optional consumer now has a deterministic pure event regression plus its
  existing real peer test. A late `:stream_open` must preserve the `:local` role
  of an already opened server stream; otherwise the fixture echoes the valid
  peer reply after sending FIN and receives `:final_size_error`. The new test
  failed before `Map.put_new` and passed afterward. No engine or dependency was
  patched, no peer timeout was increased, and no wire gate was removed.

Initial hosted candidate `5a77e06` was **not wholly green**. Its PR Foundation
run [37818762169](https://github.com/gsmlg-opt/gaoxy/actions/runs/37818762169)
failed QUIC isolation and an immediate Linux TLS refusal assertion. Its push
Foundation run [37818659912](https://github.com/gsmlg-opt/gaoxy/actions/runs/37818659912)
failed the same QUIC fixture and a macOS Registry test which waited only for UDP
before checking TCP closure. Those failures remain in the evidence; they were
not made green by rerunning unchanged tests. The second commit adds the QUIC
regression, waits for both services' monitors, and polls actual TCP refusal
within the existing bounded assertion while closing every probe and retaining
admitted TLS traffic assertions. The first PR macOS job did already run all
56 loopback cases, the external consumer and release successfully; that result
is history, not a substitute for final-candidate execution.

The next candidate `69c7a79` passed its entire PR matrix, but its push macOS job
[113458790950](https://github.com/gsmlg-opt/gaoxy/actions/runs/37820151601/job/113458790950)
still failed **2 of 56** loopback cases and skipped consumer/release. That failure
is retained in [second-candidate evidence](acceptance/evidence/m1-1/ci-second-evidence.json).
A controlled listener suspension reproduced `info.local = {:error, :outcome_unknown}`
after 53 ms; the test helper decoded that tuple as an address, causing a DNS
lookup of the atom `:error` and `:nxdomain`. The helper now validates a real IP
and port and uses its existing 2,000 ms readiness budget. Resuming the listener
restored its original address and confirmed normal cleanup; no production query
budget was changed. The separate verified-TLS handshake hit the peer's two-second
I/O timeout. The final peer uses five seconds of finite I/O tolerance for this
functional check, preserving trust/hostname rejection and every actual lifecycle
deadline. No two-second TLS latency guarantee is claimed; a shared-load cause
for that particular timeout was not proven.

Candidate `a92d2a4` retained two Linux harness failures: the push loopback TLS
refusal probe received an intermediate `:econnreset`, and the PR standalone smoke
parsed an empty readiness file between creation and completed writing. Both full
macOS portable jobs passed, including consumer and release, but that did not
make the candidate wholly green. The next commit retries the intermediate reset
while still requiring actual refusal, and parses a complete readiness document
within the existing 15-second deadline. Five deterministic harness regressions
failed before that repair and passed afterward, including explicit tests that
neither deadline is renewed. [Third-candidate evidence](acceptance/evidence/m1-1/ci-third-evidence.json)
retains the original failures and skipped steps.

Candidate `fe0e382` had a further push Linux failure in the two-service shutdown
test: immediate UDP endpoint reuse returned `:eaddrinuse` after process termination
assertions. Its matching PR Linux portable job passed all loopback, consumer and
release checks. The log omitted the conflicting socket owner, so the exact CI
cause remains unproven. A controlled real-Gaoxy probe confirmed the original
socket and all owned processes closed, then reproduced the identical error with
an unrelated socket bound to the freed endpoint. The test ran concurrently with
other ephemeral UDP allocators. Candidate `8ae2b6d` isolates that exclusive-reuse
check from other tests, captures the original socket and full owned-descendant
set, and asserts both are closed before retaining the immediate exclusive bind.
No bind retry, timeout extension or production change was added. The focused
14-test suite passes the failing seed `67737`; see the
[diagnostic](acceptance/evidence/m1-1/udp-reuse-diagnostic.md) and
[execution log](acceptance/evidence/m1-1/local-udp-reuse-focused.log).
The old push macOS release step was cancelled after the new candidate was pushed;
its loopback and consumer steps had passed, but its release is not counted as a
PASS. Both final-candidate macOS jobs subsequently executed the complete release
step successfully. [Fourth-candidate evidence](acceptance/evidence/m1-1/ci-fourth-evidence.json)
retains the failed Linux and cancelled macOS steps.

Other observed failures are distinguished from final acceptance: early Registry
rollback could briefly retain entries after process death; explicit public
`Registry.unregister/2` before termination fixed it, followed by the full green
suite. Two concurrently launched local namespace fixtures collided on Mix's
shared `/tmp` lock (`File.RenameError`, exit 1 before any network gates); their
logs were retained and only those two commands were repeated serially. The
final four matrix runs passed. Expected injected-process crashes and peer-close
errors in test output do not represent failed assertions; the optional fixture
still logs existing `:invalid_operation` termination errors after completed
connection/control scenarios, without claiming broader QUIC protocol conformance.

## Remaining boundaries and verdict

The original macOS issuer-error mechanism cannot be reconstructed from baseline
logs: executable/version/config/certificate artifacts were not captured. Both
Linux OpenSSL 3.6.3 and LibreSSL 4.2.1 verified the original fixture locally.
Thus replacing the tool alone is not claimed as the proven historical root
cause. Reproduced profile/tool-selection/diagnostic defects were fixed explicitly,
and current macOS verification must be judged from the full candidate job.

Product restrictions remain **UNSUPPORTED**, rather than blocked execution:
QUIC pause/full application or protocol drain, QUIC DATAGRAM/mTLS/migration/0-RTT,
custom `ex_ssl` server TLS, IPv6 broadcast, socket-backend IPv6 scoped sends,
and platform-rejected multicast controls. HTTP/WebSocket/Plug/Phoenix/proxy
features are outside M1.1. Outer supervisor deadlines and abrupt termination
limits are described above and in ADR 004. No package was published or deployed.

**M1.1 acceptance complete for executable candidate
`8ae2b6db0a025461ef660148ef96de9a9ce280c3`.** The final local suite and every
required hosted platform, network, consumer, release and optional-QUIC gate pass
on the recorded candidate inputs and locked dependencies. No M1.1 execution
gate remains FAIL, BLOCKED or NOT RUN. The historical issuer/port-owner
uncertainties and unsupported product capabilities above remain explicit;
this verdict does not extend beyond M1.1.
