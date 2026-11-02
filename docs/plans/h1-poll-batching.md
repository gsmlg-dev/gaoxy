# Bounded HTTP/1 connection polling

Issue: [#19](https://github.com/gsmlg-dev/gaoxy/issues/19). Baseline:
`bc1976da76b1d7c83ca79cc553ae2bcfec69a809`.

## Design

Keep the existing synchronous H1 exchange and admission ownership. Each public
poll may retain a batch bounded by 8 KiB, `max_read_chunk`, and the remaining
`max_buffer_bytes` capacity. A full buffer still permits exactly one observation
byte: only actual excess input rejects the valid inclusive boundary.

This extends [issue 11's design](../designs/issue-11-poll-boundary.md) only by
replacing its below-boundary single-byte granularity. Its inclusive boundary,
terminal excess handling, returned-state and admission-before-read contracts
remain effective; the historical design and evidence stay unchanged.

Before receiving, admit the complete old-buffer/received-batch/concatenation peak,
`2 * (buffer_bytes + batch_bytes)`, retaining its conservative floor across later
operations. If admission rejects a batch with `:byte_limit`, retry a smaller batch;
other admission errors remain terminal and no rejected read consumes input.

Exact-length socket receives try one full batch with zero wait. On a short/idle
result, accumulate one-byte reads within that same admitted batch. Only its first
byte may wait, bounded by the original request deadline and the public poll's
finite wait. Later bytes use zero wait. Return every consumed prefix in the
updated exchange, including when EOF, another error or the original deadline
terminates the batch. Body-read semantics, H2 stream isolation,
funding/repartition and live lease checks stay unchanged.

Repeated exact-size halving was rejected after an executed raw TCP reproduction:
65,533 input bytes plus write-side EOF; at 57,344 retained bytes, `recv(8192, 0)`
timed out and `recv(4096, 0)` returned 4,096 bytes. The next `recv(4096, 0)` returned
`:closed`, discarding the remaining 4,093 bytes; a one-byte read then returned
`:enotconn`. One-byte fallback within the batch avoids this loss while retaining
one admission before and after each batch, instead of per-byte admission.

## Plan and acceptance

1. Reproduce the per-byte public-poll regression -> verify: 64 KiB plus EOF fails
   a finite 64-poll bound on the baseline.
2. Implement bounded reads and pre-admission -> verify: that regression passes,
   with exact retained content, deadline, inclusive boundary and pre-recv charges.
3. Update affected contract tests and docs -> verify: short/idle input, byte-credit
   fallback, stale leases, exact cap/+1, EOF and keepalive through active protocol
   tests; preserve assertions about no consumption and full memory peaks.
4. Independent review and fresh verification -> verify: scoped exact-count gates,
   formatting, warnings-as-errors compilation, inventory and diff checks pass.

## Task record

`ROUTE task=issue19_h1_batch agent=sol_worker reason=user_authorized_bounded_implementation`

- Initial/current worker: `sol_worker`; mode: implementation.
- Sol/Astra escalated: false/false; Sol repair rounds: 2 (round 2 complete);
  Astra repair rounds: 0.
- Astra gate: none. Expected TDD reds are recorded separately from repair rounds.
- Implementation environment: macOS, Elixir 1.20.1 / OTP 29. Parent acceptance
  used Elixir 1.18.5 (compiled with OTP 27), running on OTP 29. Linux CI is not run.
- Publication, version changes, dependency source patches and architecture changes
  are outside this task.

## Verification record

- Expected TDD red: baseline consumed only 64 bytes in 64 public polls; the
  64 KiB+EOF regression failed. Initial batch implementation passed that case.
- Initial scope: 41/42 passed. The TLS fixture required zero-wait close detection
  unsupported by the unchanged OTP 29 `:ssl.recv(socket, 1, 0)` call. A standalone
  TLS probe returned `:timeout` with wait 0 and `:closed` with wait 100. The fixture
  now uses a finite wait and preserves exact prefix size/digest and EOF assertions.
- Sol round 1: 42/43 passed. Added non-power-of-two TCP input exposed the raw
  exact-receive loss described above; TLS content/EOF assertions passed.
- Sol round 2: safe prefix accumulation passed the complete changed scope, 43/43,
  exit 0. Separate exact-count executions also passed 14 connection-poll,
  22 native-seam and 7 poll-boundary cases, with no exclusions or skips.
- Additional active compatibility checks passed 7 exchange-peer-close,
  2 network-peer-close, 3 H1-resource and 19 mixed-connection-lifecycle cases
  (74 passing cases across the seven individually checked files, exits 0).
  Each used `unbuffer python3 scripts/check-tests.py <path> --seed 0 --max-cases 1`
  and the positive expected counts from `scripts/check-repairs.py`.
- Initial broader H2 checks were environment-blocked: H2 resources ran 9/10,
  request lifetime ran 8/10 (their exact-count wrapper exited 1), and H2 stream
  lifetime ran 1/2 (exit 2). All four failures required the absent
  `.audit/h2peer/bin/python`; the system Python also lacked `hpack`.
  Provisioning the workflow's pinned H2 requirements in that exact venv succeeded:
  `h2==4.3.0`, `hpack==4.2.0`, `hyperframe==6.1.0`. Fresh exact-path reruns passed
  10/10 H2 resources, 10/10 request lifetime and 2/2 H2 stream lifetime, each
  exit 0, making 96 passing cases across all ten checked files. Initial blocked
  evidence remains recorded; no source, test or assertion was changed to bypass it.
- Scoped `mix format --check-formatted` passed for all five modified Elixir files.
  Repository-wide formatting failed on five unchanged files under local
  Elixir 1.20.1: HTTP2 connection, HTTP1 parser test, two managed-H2 proxy tests
  and the Phoenix ownership example. Their source matches HEAD.
- `MIX_ENV=test unbuffer mix compile --warnings-as-errors` failed on unchanged
  bitstring pin warnings in `websocket.ex:489` and `websocket/frame.ex:85,160,210`
  under OTP 29. The exact CI toolchain (Elixir 1.18.5 / OTP 28.5) is unavailable
  locally. No unrelated source was modified.
- Inventory passed: unit=390, component=323, protocol=192; 121 active and
  143 retained files. Python script regressions passed 8 `test-check-tests`,
  9 `test-check-repairs`, and 14 `test-check-test-inventory` cases. All exited 0.
- Independent Sol review passed specification, code and test inspection with no
  actionable findings. Its preliminary deadline concern was retracted after
  confirming `update_body_retention` enforces the expired original deadline.
- `git diff --check` passed; `mix.lock` and historical issue-11 documents are
  unchanged. No assertion or historical evidence is removed.

## Parent fresh acceptance

All commands below passed after independent review, against the same uncommitted
implementation on baseline `bc1976da76b1d7c83ca79cc553ae2bcfec69a809`.
The parent used the installed Elixir 1.18.5 compiler with OTP 29 and isolated
`MIX_BUILD_PATH=.audit/issue19/elixir18-build`, with `MIX_ENV=test`.

- Repository-wide `unbuffer mix format --check-formatted`: exit 0.
- Fresh umbrella `unbuffer mix compile --warnings-as-errors`: exit 0, no warnings.
  The earlier Elixir 1.20.1 failures remain recorded above; no source was changed
  to resolve those compiler/formatter version differences.
- The following fresh test execution passed 96/96 in 9.2 seconds, exit 0, with
  no excluded or skipped cases:

  ```sh
  unbuffer python3 scripts/check-tests.py \
    apps/gaoxy_http/test/{connection_poll,native_proxy_seams,poll_boundary_network}_test.exs \
    apps/gaoxy_http/test/{exchange_peer_close,exchange_peer_close_network,resource_budget_h1,resource_budget_h2}_test.exs \
    apps/gaoxy_http/test/{mixed_connection_lifecycle,request_lifetime_network,stream_lifetime_h2}_test.exs \
    --seed 0 --max-cases 1
  ```

- Fresh inventory: unit=390, component=323, protocol=192; 121 active and 143
  retained files, exit 0. Final diff checks passed.

The local implementation and ordinary scoped acceptance are complete. Exact
Linux/OTP 28.5 CI and publication were not run. OTP 29's existing TLS zero-wait
closure limitation remains; the TLS EOF regression uses a finite wait.

## Separate 0.14.1 patch-release task

`ROUTE task=issue19_patch_release agent=sol_worker reason=user_authorized_direct_main_patch_release`

The user separately authorized fixing issue #19 on `main`, committing the fix and
publishing the next patch. Release preparation starts from baseline
`bc1976da76b1d7c83ca79cc553ae2bcfec69a809` with the accepted, uncommitted
implementation above. This is a separate metadata task: Sol/Astra repair rounds
start at 0/0, no escalation gate. The implementation's Sol 2/Astra 0 history is
unchanged. The parent owns Git changes and publication; the metadata worker does
not commit, push or publish.

1. Set all seven own manifests and current installation guides to 0.14.1 ->
   verify: versions agree, with historical release/design/acceptance evidence and
   vendored WebSockAdapter 0.6.0 provenance preserved.
2. Add patch-release notes describing the accepted H1 batching fix -> verify:
   notes cover bounds, admission, short reads, inclusive limits, content, EOF,
   deadlines and accounting without claiming unmeasured performance.
3. Check canonical formatting, package regressions and exact six-package staging
   -> verify: all packages use 0.14.1 and exact own requirements, with no changes
   to implementation, tests, workflows, lockfiles or vendor provenance.
4. Parent independent review, final source qualification, commit and publication
   -> verify: exact committed source, workflow and published artifacts are read
   back before declaring release completion.

### Metadata verification

Local checks used macOS, Elixir 1.18.5 (compiled with OTP 27), running on OTP 29,
with `ELIXIR_ERL_OPTIONS='+S 2:2'` and `MIX_ENV=prod`. Source remains an uncommitted
0.14.1 candidate on baseline `bc1976da76b1d7c83ca79cc553ae2bcfec69a809`.

- All seven own manifests declare exactly 0.14.1. Current installation guides
  agree; historical release/design/acceptance evidence remains unchanged.
  Vendored WebSockAdapter's source version remains 0.6.0.
- Canonical repository-wide `unbuffer mix format --check-formatted`: PASS, exit 0.
- The first `python3 scripts/test-stage-hex-packages.py` run executed 12 tests
  with seven failure entries because the existing Hex 2.5.4 archive called
  `Enum.__in__/2`, unavailable under Elixir 1.18.5. No repository source or test
  was changed. Installing official Hex 2.6.0 with `mix local.hex --force` into
  isolated `MIX_ARCHIVES=.audit/issue19/elixir18-archives` succeeded, preserving
  global archives. The identical regression command then passed all 12 tests
  in 24.232 seconds, exit 0. This environment repair does not increment product
  repair counters; the initial failure remains recorded.
- Actual staging with `elixir scripts/stage-hex-packages.exs` into
  `.audit/issue19/hex-0.14.1-q02tay2l` passed, exit 0. Loading all six generated
  project manifests confirmed version 0.14.1 and all seven exact own dependency
  requirements `== 0.14.1`, including the adapter's Hex alias and the test
  package's optional HTTP/3 dependency. Runtime `lib`/`priv` payload digests and
  each staged README match their current source; no runtime source was rewritten.
- `git diff --check`: PASS. Implementation, tests, workflows, lockfiles and vendor
  provenance retain the accepted source. Metadata task counters remain Sol 0 /
  Astra 0, with no escalation gate.

Independent release metadata review passed with no findings. The metadata worker
has completed its assigned preparation and relinquishes all writes and serialized
build ownership to the parent. Final release-source qualification, commit and
publication remain pending. The implementation checks above apply to their stated
unversioned source and do not substitute for final release verification.

### Parent versioned-source acceptance

After independent metadata review and the worker's stopped-command handoff, the
parent checked the final 0.14.1 source with canonical Elixir 1.18.5 on OTP 29,
`MIX_ENV=test`, isolated `MIX_BUILD_PATH=.audit/issue19/elixir18-build` and the
compatible isolated Hex archive. Repository-wide formatting, strict umbrella
compilation, the same ten-file 96-case selection, inventory and diff checks all
passed with exit 0. The 96 cases completed in 8.7 seconds without failures,
exclusions or skips; inventory reports unit 390, component 323 and protocol 192.
Logs are retained locally under `.audit/issue19/release0141/`.

At this pre-commit checkpoint, local acceptance and both independent reviews are
complete. Commit/push, all five Linux/native-platform source workflows on the
exact publication SHA, guarded release dispatch and public artifact read-back
remain pending. They must pass before delivery is declared complete.
