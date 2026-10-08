# M1.1 hardening acceptance — candidate validation in progress

Date: 2026-10-09 (Asia/Shanghai). Scope is F1–F5 in the supplied
`gaoxy-m1.1-fix-prompt.md`; M2 and new transport/protocol features are excluded.
The historical M1 snapshot is not reused as passing evidence for these changes.

## Source and environment

Initial checkout: `main`, `adafa668937ed9a919cc82fcae14ae50863b5ac6`.
Only `gaoxy-m1.1-fix-prompt.md` was untracked initially; it is preserved and is not
part of the candidate commit. No reset or dependency-source modifications occurred.
Tests below ran against that SHA **plus the implementation diff**, not unchanged
baseline source. A dedicated `codex/m1-1-hardening` worktree under `.trees` is used
for hosted candidate validation while the original checkout retains the fixes.

Local host: NixOS Linux x86_64, kernel 6.18.33; Elixir 1.18.5, OTP 28,
ERTS 16.4.0.5. Commands set `ELIXIR_ERL_OPTIONS='+S 2:2'`.
OpenSSL executable `/run/current-system/sw/bin/openssl`, version 3.6.3.
Independent ordinary peer: CPython 3.13.15/OpenSSL 3.6.3.
Abyss 0.7.0 is locked to `9b710e6480900e16e304f40e63623aff8c922e19`;
Thousand Island 1.5.0 to `6146e1bfdd1a85c5c16c3c92ad98ff5f11066820`;
Telemetry 1.4.2. Lockfiles and installed dependency sources remain unchanged.
UDP `inet` and `socket` backends run separately. Runtime-matrix CI additionally
requires Elixir 1.18.5/OTP 28.5 and Elixir 1.20.1/OTP 29.0.2.

## Revalidation and implementation

| Finding | Baseline classification and cause | Implemented behavior and regression evidence |
|---|---|---|
| F1 | **REPRODUCED**: actual parent Supervisor shutdown killed admitted TCP/UDP work before emitting a drain transition. Service termination stopped the gate first. | Instance dispatches concurrent service barriers and retains callback loops/I/O under one absolute deadline. TCP, verified TLS and UDP parent tests cover both completion and forced closure; UDP proves the original response source port and later exclusive bind reuse. Two stalled services have exactly equal deadlines and both closed gates before cleanup. Standalone SIGTERM test holds admitted TCP/TLS clients until their responses finish. |
| F2 | **REPRODUCED**: killing the public registration owner allowed real TCP/UDP exchanges while lookup remained missing. Registry startup also leaked an ArgumentError instead of the documented error. | Monitored lifecycle/telemetry owners; one bounded reconciliation timer; both bindings restored under the same generation, or confirmed fail-closed closure. Tests cover partition/whole Registry replacement, abrupt root death, sustained outage, paused/draining services, startup, two instances with identical IDs, telemetry attribution, partial registration, stale timers and replacement. Registry-backed instance names themselves fail closed on owner loss. |
| F3 | **REPRODUCED**: killed drain helper returned `:ok`; deadline code sent kills without confirmation; instance stop discarded removal errors. | Confirm resources and service/instance exit; helper errors/exceptions/normal exit without completion trigger emergency cleanup and structured errors. Caller deadlines return uncertainty, failures aggregate, caller death does not abandon cleanup, duplicate operations are bounded, stale messages cannot affect a replacement. Regressions retain real socket/lease cleanup assertions. |
| F4 | **REPRODUCED**: removing a required TCP backend child made suspend fail after the gate had closed, leaving advertised `:ready`. | Explicit pausing/resuming transitions; commit only after backend and gate success. Backend error/exit/timeout leaves fail-closed state; uncertain gate coordination forces cleanup. Repeated calls, backend failures, gate failures after backend success and late resume during drain are covered. |
| F5a | **REPRODUCED** locally and in baseline static run `37759455187`: Elixir 1.18.5 formatter rejected guarded layout in service/config; compilation was **skipped**, not failed. | Canonical formatter 1.18.5 in an independent job; older/newer runtime compile/test matrices retained. Formatting, strict local compilation and idempotence checked. Test-count harness now rejects all-excluded/all-skipped runs in both ExUnit formats. |
| F5b | Baseline macOS failure **REPRODUCED from logs**, underlying issuer-error cause **NOT REPRODUCED / NEEDS EVIDENCE** locally: run `37759455253`, job `113252030848` failed two fixture verifications before any TLS listener started. Tool/config/certificate artifacts were absent; consumer/release steps were skipped. | Concrete portability defects reproduced and fixed: ignored OPENSSL_BIN, dependence on machine profiles, hidden generation diagnostics. Validated OpenSSL 3 executable, explicit CA/leaf extensions/SAN/EKU/SKI/AKI, isolated serial/signing files, restrictive permissions and strict chain/purpose/DNS/IP checks. Wrong-CA and wrong-hostname negatives plus real verified TLS remain. Linux OpenSSL and LibreSSL both passed the original issuer check, so tool replacement alone is not claimed as the causal diagnosis. Full candidate macOS execution is required. |

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

## Gate ledger

This initial ledger records actual local executions; final candidate CI and the
remaining gates are pending. Counts include only selected/executed cases, never
excluded cases or configured workflow definitions.

| Gate | Status | Evidence so far |
|---|---|---|
| Initial full local suite | PASS | `python3 scripts/check-tests.py --seed 0`: exit 0, 54 core + 1 server tests, 0 failures, no exclusions; later review regressions require final rerun |
| Expanded lifecycle focus | PASS | `mix test apps/gaoxy/test/shutdown_hardening_test.exs apps/gaoxy/test/lifecycle_fault_test.exs --warnings-as-errors --seed 0`: exit 0, 22 tests, 0 failures |
| Registry/ownership/backend attribution focus | PASS | Initial combined focus: exit 0, 12 tests, 0 failures; added named-instance cases require final rerun |
| Local formatter / strict compile | PASS | `mix format --check-formatted`, `mix compile --warnings-as-errors`: exit 0 on local 1.18.5; final candidate rerun pending |
| Fixture + verified TLS focus | PASS | 4 tests, 0 failures; wrapper process regressions separately 8 tests, 0 failures |
| Linux portable release | PASS | Initial production compile/build + enhanced `python3 scripts/release-smoke.py`: exit 0, TCP/TLS/UDP traffic, admitted stream replies after SIGTERM barrier, VM exit and UDP bind reuse |
| Isolated Linux inet IPv4 | PASS | `python3 integration/network/fixture.py --allow-privileged`: exit 0, 13 gates |
| Isolated Linux inet IPv4/IPv6 | PASS | Same with `--ipv6`: exit 0, 21 gates |
| Isolated Linux socket IPv4 | PASS | Same with `GAOXY_UDP_BACKEND=socket`: exit 0, 13 gates |
| Isolated Linux socket IPv4/IPv6 | PASS | Socket plus `--ipv6`: exit 0, 20 gates; scoped-send unsupported negative retained |
| Final independent core consumer | NOT RUN | Pending final candidate freeze |
| Final five-transport release/example | NOT RUN | Prepared Linux namespaces available; pending final release rebuild |
| Optional independent QUIC | NOT RUN | Exact locked native dependencies and CPython 3.12.13/aioquic 1.2.0 now provisioned; final candidate test pending |
| Candidate Linux/macOS hosted matrix | NOT RUN | Isolated candidate branch not yet published; full macOS job including consumer/release must execute |

**M1.1 acceptance incomplete** until the final candidate gates above execute and
the ledger is reconciled. Historical passing network/QUIC records are not used to
fill these pending rows.
