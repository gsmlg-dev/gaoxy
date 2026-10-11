# Portable release bounded recovery handoff

Task: release-0.2.0-portable. Status: ESCALATE_TO_ASTRA.
Assignment: direct portable release implementation, now parent-managed bounded recovery.
Gate: SOL_REPEATED_FAILURE (parent validated and dispatched portable_build_astra1).

## Exclusive ownership

Repository/worktree: /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway
Frozen source and HEAD: 32ec599790ccddb477345a765681f74852e5ffc0
Own only this .audit/release-0.2.0-portable directory. Parent owns tracked source/docs/publication.
At shutdown, unrelated tracked edits were AGENTS.md and docs/acceptance/release-0.2.0.md;
untracked docs/acceptance/evidence/release-0.2.0/hosted-run.json. This worker changed none of them.
Do not edit host deps/_build, tracked source, tests, or assertions. Do not publish.
Do not investigate/query/replace/enforce dismissed http_fetch#97.
Do not query or change account, billing, permissions, release settings, or visibility.
Retain Vault, deployment, production-data, operational-certificates, public-management,
and disabled release-artifact E2E restrictions.
No source or fixture repair is required for the established alert difference.

## Counters and real outcomes

Portable Sol repairs 2; unsuccessful 2; portable Astra repairs 0 at this handoff.
Historical successful smoke Sol repairs1/unsuccessful0 are retained.
Historical H1/TLS counters are parent-owned and must not be reset; exact values unknown here.
Initial build was not a repair: exit1, compatibility486 tests/2 failures on OTP28.5.
Repair1: patched profile, GNU timeout1800 expired with actual exit124.
Repair2: cached continuation under remaining total2400s allowance, GNU timeout539,
actual exit124 after542.009s including cancellation shutdown, completed13:03:18.963Z.
All inner build/test/smoke/application assertions and deadlines remained unchanged.
Parent now authorizes recovery builder1800s/runtime600s; no third Sol attempt was launched.

## Confirmed cause of original red

apps/gaoxy_proxy/test/websocket_tls_test.exs:70 asserts peer bad_certificate at96.
apps/gaoxy_proxy/test/http_proxy_tls_test.exs:111 asserts peer bad_certificate at135.
Both passed downstream502, downstreamclosed, and no-success assertions first.
OTP28.5 emitted local bad_cert/hostname_check_failed but peer handshake_failure.
Upstream ssl_handshake.erl maps hostname_check_failed to HANDSHAKE_FAILURE on OTP28.5,
and to BAD_CERTIFICATE on OTP28.5.0.2 and OTP28.5.0.5. Snapshots/hashes and exact probe
are preserved in evidence/tls-root-cause.json and evidence/OTP-*-ssl_handshake.erl.
Fixture 'verification was not requested' is secondary: the pinned alert assertion aborts
before assert_no_replay sends verify_no_replay. It does not show a verification bypass.
Patched-image direct TLS probe exit0: both client and peer bad_certificate, local
hostname_check_failed, OTP28.5.0.5, SSL11.6.0.4, networknone. Diagnostic only.

## Selected recipe, retained unchanged since repair1

context/Dockerfile and context/build.py select builder:
hexpm/elixir@sha256:abbfaf9699b7a3650810c92268023806217486c26b4da3dc0492a778b22a09bb
Tag: 1.19.6-erlang-28.5.0.5-debian-bookworm-20260824-slim
Actual imageID: sha256:1b4af9b743237ebe684f327c1b6e588b9269af24be9b768969ce8e76ad83528a
linux/amd64, OTP28.5.0.5 / ERTS16.4.0.5 / SSL11.6.0.4.
The image Elixir is overridden by exact official Elixir1.18.5 source compilation,
commit dfe6612e546cec6557900e67651f7d21805472ef, /opt/elixir/bin first in PATH.
Rust image remains sha256:0e2bcaef56d041a486784e54104a81aebe0da44bd03019bd70bc0401e42e4a97.
Rust/Cargo1.97.1; Python3.11.2; OpenSSL3.0.22; glibc2.36-9+deb12u14.
Exact OTP assertion and build-info builder identity were updated together.
Original recipe snapshots: evidence/initial-Dockerfile and evidence/initial-build.py.
Source input is clean git archive of frozen SHA; tar commit ID verified.
Source archive sha256: 44418e6dd6190af9b69826f08675310157eb6987831f3b1d6596fa2e37faa86d
No host dependency/build mounts are used.

## Why bounded retries did not finish

Repair1 spent over1200s in clean Debian apt download/install, then exact Elixir compilation.
It was canceled during production compilation; compatibility/package/runtime NOT RUN.
Repair2 correctly cached all Debian/Elixir/source layers, but combined build.py RUN
repeated dependency retrieval (~270.7s), peer setup (completed283.9s), then production
compilation (completed500.2s). Compatibility started with insufficient outer budget;
no completed test summary is available before cancellation. No new assertion failure
was observed; this is incomplete qualification, not a passing gate.
The Dockerfile currently places all dependency retrieval, format, compile, compatibility,
release, smokes and packaging in one RUN. Canceled RUN discards its dependencies/NIF
build output. Completed foundation layers are retained. This is the specific recovery
opportunity; preserve unchanged gates, clean input and honest phase/check exits.

## Current assets and unfinished acceptance

artifacts/ is empty. No qualified archive, build-info or SHA256SUMS exported.
Need unchanged canonical format, strict production compile, exactly486 executed tests,
zero failures/exclusions/skips, release, unchanged build-side core3/gateway2 smokes,
source-file hash comparison, archive export and final two-entry checksums.
Run context/finalize.py <artifact-directory> after successful export; it hashes archive
AND build-info.json and verifies required counts/check exits. Do not publish.
Then independently qualify packaged release in fresh pinned Debian bookworm container,
networknone, artifact mount readonly, evidence writable; every ELF readelf/ldd must have
no missing libraries or /nix/store dependencies; unchanged packaged core3/gateway2 smokes.
Support only tested Debian bookworm/glibc x86_64. Broader platform claims unqualified.
Runtime base sha256:a4672c0cb26fbdde88e38fa2dfb6c681942306680e41e4378b28770b6e79ee91.
Prepared helpers context/runtime.py, run_runtime.py, qualify_runtime.py are syntax checked
but runtime NOT RUN. qualify_runtime.py bounds runtime image build plus qualification600s;
run_runtime.py captures actual imageID, live/final container inspect/networknone, logs,
owned removal. Parent may review/helpers adapt in owned scope; never weaken inner checks.

## Evidence and shutdown

All evidence is under /home/gao/Workspace/gsmlg-opt/gaoxy/.trees/m3-gateway/.audit/release-0.2.0-portable/evidence:
docker-build-initial.log (486/2), docker-build-repair1.log (exit124),
docker-build-repair2.log (exit124), repair-history.json, tls-root-cause.json,
hostname-probe-patched.log, patched builder manifest/image inspect, registry snapshots,
shutdown.json with full log hashes and actual client sessions/exits.
No running owned artifact commands or probe containers remained at13:04:46Z;
BuildKit acknowledged both cancellations. Docker client sessions completed; helpers never
started runtime. No processes/images/dependencies belonging to others were stopped or removed.
Current worker now stops all mutations; parent owns final review and publication decisions.
