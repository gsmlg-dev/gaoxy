# Gaoxy 0.12.0 release acceptance

Date: 2026-10-22, Asia/Shanghai. The user requested internal-request fixes
directly on `main` and the next version release. The initially clean source was
`0b3f97fc08549649b4b367e3a85a8526e162f53f`. The local results below cover its
reviewed working-tree changes; logs that print `REPAIR_SOURCE` show that base
commit. Hosted and publication checks must additionally qualify the exact
committed source, recorded after publication.

## Accepted behavior

- #12: HEAD preserves validated declared representation Content-Length,
  suppresses the body, and retains existing status/framing validation.
  Independent H1/H2/H3 peers check 16 rows per protocol, 48 total.
- #13: ordinary native/Plug H1/H2 targets accept the explicit
  `http_limits: %{request_timeout: :infinity}` option. Finite defaults,
  header/read/write limits, startup admission, cancellation and shutdown
  remain bounded. File responses inherit the request lifetime. Direct or
  wrapped Generation, managed gateway and H3 targets explicitly reject the
  option before target initialization/preparation.
- #14: Phoenix's exact `{:shutdown, :disconnected}` WebSock result closes
  with 1000 and calls terminate with `:normal`. Restart/error/explicit-code
  behavior retains its established contract. A real Phoenix channel
  broadcast verifies wire closure and transport/channel cleanup.

All seven own application/root manifests advance to 0.12.0. The six Hex
distributions advance together. Dependency pins and vendor provenance are
unchanged. No deployment, production data, operational certificate, Vault,
public management or deferred specialist qualification is included.

## Fresh local verification

Environment: Linux NixOS; Elixir 1.18.5, OTP 28, Python 3.13.15. Mix commands
use `ELIXIR_ERL_OPTIONS='+S 2:2'`. The pinned independent peer environment
contains h2 4.3.0 and aioquic 1.2.0. All PASS entries exited 0.

| Check | Result |
| --- | --- |
| `python3 scripts/check-repairs.py all` | PASS: 452 executed; unit 193, component 137, protocol 122; 0 failures, exclusions or skips |
| Focused request-lifetime/configuration/accounting regressions | PASS: 26 tests, 0 failures |
| Full Phoenix fixture: `PHOENIX_NATIVE_H3=1 python3 ../../scripts/check-tests.py --seed 0 --max-cases 1` in `examples/phoenix_native` | PASS: 23 tests, 0 failures |
| `python3 scripts/test-stage-hex-packages.py` | PASS: 10 packaging regressions |
| `python3 scripts/test-check-repairs.py` | PASS: 9 tests |
| `python3 scripts/test-check-test-inventory.py` | PASS: 14 tests |
| `python3 scripts/test-check-tests.py` | PASS: 8 tests |
| `mix format --check-formatted` | PASS |
| `MIX_ENV=prod mix compile --warnings-as-errors` | PASS |
| `git diff --check` | PASS |

The canonical manifest classifies all new app test files and schedules the
14-test controlled WebSocket stream file as component coverage. Its retained
inventory entry is removed. Unit cases use controlled/pure contracts; real
listeners and independent peers run in the protocol or Phoenix fixture gates.

The focused request-lifetime run used
`python3 scripts/check-tests.py apps/gaoxy_http/test/stream_lifetime_config_test.exs apps/gaoxy_http/test/http2_worker_accounting_test.exs apps/gaoxy_http/test/request_lifetime_network_test.exs apps/gaoxy_http3/test/stream_lifetime_boundary_test.exs apps/gaoxy_proxy/test/gateway_plan_test.exs --seed 0 --max-cases 1`.

## Review and preserved failures

[Independent review](evidence/internal-requests-0.12.0/review.md) passed after
the configuration-wrapper and finite `100 Continue` send-deadline repairs.
The #12 writer was reviewed by the #14 writer; the #12 writer independently
reviewed #13 and #14. Final fresh gates followed the resolved findings.

Raw parent logs are retained as deterministic gzip copies under
`evidence/internal-requests-0.12.0/`. This includes original #13 RED/review
failures and the first failed accounting/test-fixture attempt, the earlier
451-test PASS, and the final 452-test PASS. The original #14 green Phoenix
log is preserved too. #12 and #14 RED commands/counts were reported in worker
tool transcripts; their plans record those observations without inventing
raw log files. Historical failed runs are not relabeled by later passes.

**FAIL, separate unscheduled compatibility run:** the #12 worker executed
`http_network_test.exs` and `http2_integration_test.exs`: 37 tests, 1 failure
at `apps/gaoxy_http/test/http_network_test.exs:351`, “one large client write
streams through a smaller parser buffer”. The response was 500 instead of
the expected body `2000`. Baseline status was not established. Investigation
of that unrelated failure stopped; no assertion or production workaround
was changed. These files retain their existing unscheduled disposition.
The 452-test ordinary gate does not claim to cover that failure or the
deferred specialist suites.

## Exact-source hosted workflows

Publication source: `fbe59b76a68af38bce058456032f54dea5e28fd2`, pushed directly
to `main`. All five source workflows completed successfully: 10 required jobs
executed and passed. Raw run/job metadata and executed-count logs are preserved
in `source-ci-raw.tar.gz`, with readable `source-ci-receipt.json` and
`source-ci-counts.json` alongside it in the evidence directory.

| Workflow | Run | Result |
| --- | --- | --- |
| Static checks and build | [39739932526](https://github.com/gsmlg-dev/gaoxy/actions/runs/39739932526) | PASS: format/inventory and build |
| Unit tests | [39739932512](https://github.com/gsmlg-dev/gaoxy/actions/runs/39739932512) | PASS: 193 app cases plus script regressions |
| Integration and end-to-end tests | [39739932500](https://github.com/gsmlg-dev/gaoxy/actions/runs/39739932500) | PASS: 137 component, 122 protocol, isolated-network; separate manual release-clients job skipped |
| Portable HTTP smoke | [39739932505](https://github.com/gsmlg-dev/gaoxy/actions/runs/39739932505) | PASS: Linux and macOS start/GET health/stop |
| Package and consumer qualification | [39739932571](https://github.com/gsmlg-dev/gaoxy/actions/runs/39739932571) | PASS: package and optional-QUIC jobs |

## Publication status

The guarded [release run 39740781358](https://github.com/gsmlg-dev/gaoxy/actions/runs/39740781358)
was dispatched with version 0.12.0 and the exact full publication SHA above.
**PASS:** qualification, publication and fresh public consumers completed.
[Gaoxy v0.12.0](https://github.com/gsmlg-dev/gaoxy/releases/tag/v0.12.0) is a
stable, non-draft GitHub release. The remote tag points to the publication SHA.
The subsequent evidence-only commit on `main` does not move this tag.

| Release gate | Result |
| --- | --- |
| Isolated core, HTTP, H3 and gateway source consumers | PASS: five consumers, 9 tests |
| Ordinary correctness suite on exact publication source | PASS: 452 executed, 0 failures, exclusions or skips |
| Built-package consumers and production isolation | PASS: 7 tests; helper/ExUnit absent from production release |
| Unified Phoenix independent peers | PASS: 8 checks, including H1/H2/H3, H2/H3 channels, reload/restore and shutdown |
| Selected Phoenix certificate/message/stream/disconnect regressions | PASS: 18 tests |
| Formatting, strict compilation and source-built standalone smokes | PASS: core, H1/H2 gateway and H3 |
| Build/publish six Hex distributions, compare public archive bytes | PASS |
| Fresh `test-consumers.py --published --version 0.12.0` | PASS: base/H3/http_fetch consumers, 7 tests plus production release isolation |
| GitHub release assets and standalone metadata | PASS: Linux archive, six Hex archives and SHA256SUMS |

`release-qualification.json`, raw `release-run.json`, `release.log.gz` and the
unified Phoenix report/server log preserve the actual hosted results. The
published consumer checker already ran in the release workflow; its success
is hosted public-package evidence, not an unexecuted local duplicate.

Independent post-publication read-back used
`python3 .audit/release-0.12.0/verify-public-artifacts.py --sha fbe59b76a68af38bce058456032f54dea5e28fd2`:
**PASS**, exit 0. It downloaded and verified all 8 GitHub assets, their declared
digests/sizes and the exact 7 payload checksums; all 6 public Hex API releases
are 0.12.0 and unretired, with matching archive checksums and byte-identical
GitHub/Hex tarballs. All 135 packaged `lib/**/*.ex` files match `git show` of the
exact publication commit: core 22, HTTP 45, H3 10, proxy 42, test helper 12,
adapter 4. The Linux archive's release/start metadata and all 5 own bundled
runtime applications report 0.12.0. The remote tag was checked twice.
`public-artifacts-receipt.json`, raw release/Hex metadata and the verifier
script retain this evidence. Downloaded binary assets remain in the ignored
local audit directory; they are not added to the source repository.

## Additional public-package issue regressions

The prepared fixtures match the exact committed test/support bytes. Their
consumer dependencies select all six public packages at exactly 0.12.0, with
the adapter mapped under Phoenix's `:websock_adapter` key. No local source
override is allowed. **PASS:** 53 executed, 0 failures, exclusions or skips;
48 independent HEAD/GET protocol rows also passed. Both fresh consumers
strictly compiled and verified all six locked and loaded public Hex versions.

| Public consumer | Result |
| --- | --- |
| Standalone issue suites | PASS: 47 tests across 9 unchanged files; HEAD metadata, H1/H2 lifetimes, H3/Generation/gateway boundaries, accounting and WebSocket stream behavior |
| Actual Phoenix fixture | PASS: 6 unchanged compatibility tests, including disconnect broadcast, wire close 1000, acknowledgment, channel/transport DOWN and TCP EOF |

Command:
`ELIXIR_ERL_OPTIONS='+S 2:2' python3 -B .audit/release-0.12.0/public-issues/attempt-03/run.py --published --python "$PWD/.audit/h2peer/bin/python"`.
The final marker is
`PUBLIC_ISSUES_PASS executed=53 failures=0 own_packages=6 version=0.12.0 phoenix=6 independent_HEAD_GET_rows=48`.
`public-acceptance-receipt.json` and `public-acceptance-evidence.tar.gz` preserve
commands, exact-source fixture hashes, both locks/provenance checks, successful
logs, the runner/preparer and earlier failed harness evidence. Dependency trees,
Mix `_build` caches and downloaded package/release binaries remain outside the
repository; the archive retains generated test fixtures.
The archive contains 149 files, with SHA256
`d2ca59927ac70e525fda3cee687ed54c51822e51bdbab0fe53079036eb1bdfe7`;
its artifact metadata and individual-file hashes are retained alongside it.

Two pre-test harness failures remain preserved: the initial runner resolved
the virtualenv Python symlink to its base interpreter (missing `h2`), and the
next attempt called `Mix.Dep.load_on_environment/1`, unavailable in Elixir
1.18.5. Neither attempt executed tests. Repairs preserve the virtualenv path
with `os.path.abspath` and use supported `Mix.Dep.load_and_cache/0`; provenance
assertions and fixture bytes are unchanged. A third fresh consumer attempt
passed after those repairs. These failures are not product test failures or
PASS. Acceptance harness Sol repair rounds: 2; Astra recovery rounds: 0.

## Issue disposition

[#12](https://github.com/gsmlg-dev/gaoxy/issues/12),
[#13](https://github.com/gsmlg-dev/gaoxy/issues/13) and
[#14](https://github.com/gsmlg-dev/gaoxy/issues/14) are CLOSED and carry
`internal request fixed`. The publication-source commit contains their
closing references. All three are resolved in the coordinated 0.12.0 release.
The separate unscheduled failure above retains its actual FAIL disposition.
